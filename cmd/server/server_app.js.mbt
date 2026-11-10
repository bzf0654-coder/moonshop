// moonshop HTTP API server — JavaScript backend running under Node.
// The host glue only owns sockets; every route decision and all business
// logic happen in MoonBit against the same @lib engine as the web demo.

let store : @lib.Store = @lib.store_new()

let catalog_json = #|[
                     #|  {"id":"kb-01","name":"机械键盘 87键","name_en":"Mech Keyboard 87","category":"peripherals","price_cents":49900,"stock":8},
                     #|  {"id":"m-01","name":"无线鼠标","name_en":"Wireless Mouse","category":"peripherals","price_cents":7900,"stock":20},
                     #|  {"id":"sd-01","name":"固态硬盘 1TB","name_en":"SSD 1TB NVMe","category":"storage","price_cents":45900,"stock":15},
                     #|  {"id":"hd-01","name":"机械硬盘 4TB","name_en":"HDD 4TB","category":"storage","price_cents":59900,"stock":5},
                     #|  {"id":"cam-01","name":"高清摄像头 2K","name_en":"Webcam 2K","category":"meetings","price_cents":32900,"stock":10},
                     #|  {"id":"hub-01","name":"七合一扩展坞","name_en":"USB-C Hub 7in1","category":"meetings","price_cents":19900,"stock":2}
                     #|]

///|
// ---------- host bridge ----------

// handler(method, url, body) must return "<status>\n<body>".
extern "js" fn start_http(
  port : Int,
  handler : (String, String, String) -> String
) -> Unit =
  #|(port, handler) => {
  #|  const http = require("node:http");
  #|  http.createServer((req, res) => {
  #|    let body = "";
  #|    req.on("data", (chunk) => { body += chunk; });
  #|    req.on("end", () => {
  #|      const out = handler(req.method, req.url, body);
  #|      const sep = out.indexOf("\n");
  #|      const status = parseInt(out.slice(0, sep), 10);
  #|      res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  #|      res.end(out.slice(sep + 1));
  #|    });
  #|  }).listen(port, () => {
  #|    console.log("moonshop API listening on http://127.0.0.1:" + port);
  #|  });
  #|}

///|
// ---------- router helpers ----------

fn respond(status : Int, body : String) -> String {
  status.to_string() + "\n" + body
}

fn ok(body : String) -> String {
  respond(200, body)
}

fn error(status : Int, message : String) -> String {
  respond(status, "{\"error\":\"" + message + "\"}")
}

/// Strip a query string: everything from '?' on is dropped.
fn path_of(url : String) -> String {
  let mut cut = url.length()
  for i, ch in url {
    if ch == '?' {
      cut = i
      break
    }
  }
  url[0:cut].to_owned()
}

///|
// ---------- routes ----------

fn handle(method : String, url : String, body : String) -> String {
  let path = path_of(url)
  match (method, path) {
    ("GET", "/api/health") => ok("{\"ok\":true}")
    ("GET", "/api/products") => ok(@lib.catalog_export_json(store))
    ("GET", "/api/orders") => ok(@lib.orders_export_json(store))
    ("POST", "/api/checkout") => api_checkout(body)
    ("GET", _) =>
      if path.has_prefix("/api/orders/") {
        let order_no = path["/api/orders/".length():].to_owned()
        match @lib.store_find_order(store, order_no) {
          Some(order) => ok(@lib.order_export_json(order))
          None => error(404, "order not found")
        }
      } else {
        error(404, "unknown route")
      }
    _ => error(405, "method not allowed")
  }
}

fn api_checkout(body : String) -> String {
  let doc = @lib.json_parse(body)
  let cart = @lib.cart_new()
  let lines_opt : @lib.JsonValue? = @lib.json_get(doc, "lines")
  match lines_opt {
    Some(lines_val) =>
      match @lib.json_as_array(lines_val) {
        Some(items) =>
          for item in items {
            let id_opt : @lib.JsonValue? = @lib.json_get(item, "id")
            let qty_opt : @lib.JsonValue? = @lib.json_get(item, "qty")
            match (id_opt, qty_opt) {
              (Some(id_val), Some(qty_val)) =>
                match (@lib.json_as_string(id_val), @lib.json_as_double(qty_val)) {
                  (Some(id), Some(qty)) => ignore(@lib.cart_add(cart, id, qty.to_int()))
                  _ => return error(400, "each line needs id and qty")
                }
              _ => return error(400, "each line needs id and qty")
            }
          }
        None => return error(400, "lines must be an array")
      }
    None => return error(400, "body needs a lines array")
  }
  if @lib.cart_is_empty(cart) {
    return error(400, "cart is empty")
  }
  // coupon by registry code
  let coupon : @lib.Coupon? = match @lib.json_get(doc, "coupon") {
    Some(code_val) =>
      match @lib.json_as_string(code_val) {
        Some(code) => @lib.coupon_from_code(code)
        None => None
      }
    None => None
  }
  // rebate flag -> the built-in 满300减30 activity
  let rebate_on = match @lib.json_get(doc, "rebate") {
    Some(b_val) =>
      match @lib.json_as_bool(b_val) {
        Some(b) => b
        None => false
      }
    None => false
  }
  let rebate : @lib.Rebate? = if rebate_on {
    Some(@lib.rebate_new(30000, 3000))
  } else {
    None
  }
  let member_pct : Int? = match @lib.json_get(doc, "member_pct") {
    Some(p_val) =>
      match @lib.json_as_double(p_val) {
        Some(v) => Some(v.to_int())
        None => None
      }
    None => None
  }
  match (match (rebate, member_pct) {
    (Some(r), Some(pct)) => @lib.store_checkout(store, cart, coupon, rebate=r, member_off_pct=pct)
    (Some(r), None) => @lib.store_checkout(store, cart, coupon, rebate=r)
    (None, Some(pct)) => @lib.store_checkout(store, cart, coupon, member_off_pct=pct)
    (None, None) => @lib.store_checkout(store, cart, coupon)
  }) {
    Some(order) => respond(201, @lib.order_export_json(order))
    None => error(409, "insufficient stock or unknown product")
  }
}

///|
fn run_server() -> Unit {
  ignore(@lib.store_import_json(store, catalog_json))
  start_http(8080, handle)
}
