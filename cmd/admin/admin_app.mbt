// moonshop admin console — same MoonBit engine, same localStorage keys
// as the shop page: restock here, the storefront reflects it on refresh.

let catalog_json = #|[
                     #|  {"id":"kb-01","name":"机械键盘 87键","name_en":"Mech Keyboard 87","category":"peripherals","price_cents":49900,"stock":8},
                     #|  {"id":"m-01","name":"无线鼠标","name_en":"Wireless Mouse","category":"peripherals","price_cents":7900,"stock":20},
                     #|  {"id":"sd-01","name":"固态硬盘 1TB","name_en":"SSD 1TB NVMe","category":"storage","price_cents":45900,"stock":15},
                     #|  {"id":"hd-01","name":"机械硬盘 4TB","name_en":"HDD 4TB","category":"storage","price_cents":59900,"stock":5},
                     #|  {"id":"cam-01","name":"高清摄像头 2K","name_en":"Webcam 2K","category":"meetings","price_cents":32900,"stock":10},
                     #|  {"id":"hub-01","name":"七合一扩展坞","name_en":"USB-C Hub 7in1","category":"meetings","price_cents":19900,"stock":2}
                     #|]

let store : @lib.Store = @lib.store_new()

let accounts : @lib.Accounts = @lib.accounts_new()

priv struct AdminState {
  mut token : String
}

let state : AdminState = { token: "" }

const ITEMS_KEY : String = "moonshop.items"

const ORDERS_KEY : String = "moonshop.orders"

const USERS_KEY : String = "moonshop.users"

const TOKEN_KEY : String = "moonshop.token"

fn save_all() -> Unit {
  @lib.storage_set(ITEMS_KEY, @lib.catalog_export_json(store))
  @lib.storage_set(ORDERS_KEY, @lib.orders_export_json(store))
  @lib.storage_set(USERS_KEY, @lib.accounts_export_json(accounts))
}

fn save_state() -> Unit {
  save_all()
}

fn restore_or_seed() -> Unit {
  let saved_items = @lib.storage_get(ITEMS_KEY)
  if saved_items != "" {
    ignore(@lib.store_import_json(store, saved_items))
    let saved_orders = @lib.storage_get(ORDERS_KEY)
    if saved_orders != "" {
      ignore(@lib.orders_import_json(store, saved_orders))
    }
  } else {
    ignore(@lib.store_import_json(store, catalog_json))
  }
}

///|
// ---------- rendering ----------

fn render_products() -> Unit {
  let buf = StringBuilder()
  for item in store.items {
    let p = item.product
    let low = if item.stock <= 3 {
      "<span class=\"low\"> · 仅剩 " + item.stock.to_string() + "</span>"
    } else {
      ""
    }
    buf.write_string(
      "<tr><td>" + category_emoji(p.category) + " " + p.name +
      "<div class=\"sub\">" + p.id + " · " + p.category +
      (if p.desc != "" { " · " + p.desc } else { "" }) +
      "</div></td><td class=\"num\" id=\"stock-" + p.id + "\">" +
      item.stock.to_string() + low +
      "</td><td class=\"num\">" + @lib.format_cents(p.price_cents) +
      "</td><td class=\"num\"><button class=\"rs\" id=\"rs-" + p.id +
      "\">补货</button> <button class=\"dl\" id=\"dl-" + p.id +
      "\">下架</button></td></tr>",
    )
  }
  @lib.get_el("products").set_html(buf.to_string())
  for item in store.items {
    let id = item.product.id
    let btn = @lib.get_el("rs-" + id)
    btn.on_click(fn() {
      let qty_text = @lib.get_el("restock-qty").get_value()
      ignore(@lib.store_restock(store, id, parse_qty(qty_text)))
      save_state()
      render_products()
    })
    let dl = @lib.get_el("dl-" + id)
    dl.on_click(fn() {
      ignore(@lib.store_remove_product(store, id))
      save_state()
      render_products()
    })
  }
}

fn render_ledger() -> Unit {
  let buf = StringBuilder()
  if store.orders.length() == 0 {
    buf.write_string("<tr><td colspan=\"4\" class=\"empty\">暂无订单</td></tr>")
  } else {
    for order in store.orders {
      let mut units = 0
      for line in order.lines {
        units = units + line.qty
      }
      buf.write_string(
        "<tr><td>" + order.order_no + "</td><td class=\"num\">" +
        order.lines.length().to_string() + " 种</td><td class=\"num\">" +
        units.to_string() + " 件</td><td class=\"num\">" +
        @lib.format_cents(order.breakdown.total) + "</td></tr>",
      )
    }
  }
  @lib.get_el("ledger").set_html(buf.to_string())
}

/// Parse a restock quantity; anything invalid or non-positive falls
/// back to the default batch of 5.
/// Parse a yuan price like "129", "129.9", "129.99" into cents without
/// any floating point.
fn parse_price_cents(text : String) -> Int {
  let mut yuan = 0
  let mut fen = 0
  let mut phase = 0
  let mut fcount = 0
  for _, ch in text {
    if ch == '.' {
      phase = 1
    } else if ch >= '0' && ch <= '9' {
      let d = ch.to_int() - '0'.to_int()
      if phase == 0 {
        yuan = yuan * 10 + d
      } else if fcount < 2 {
        fen = fen * 10 + d
        fcount = fcount + 1
      }
    }
  }
  while fcount < 2 {
    fen = fen * 10
    fcount = fcount + 1
  }
  yuan * 100 + fen
}

fn category_emoji(c : String) -> String {
  match c {
    "peripherals" => "⌨️"
    "storage" => "💽"
    "meetings" => "🎥"
    _ => "📦"
  }
}

fn parse_qty(text : String) -> Int {
  let mut n = 0
  for _, ch in text {
    if ch >= '0' && ch <= '9' {
      n = n * 10 + (ch.to_int() - '0'.to_int())
    }
  }
  if n <= 0 {
    5
  } else {
    n
  }
}

///|
fn wire_admin_actions() -> Unit {
  @lib.get_el("restock-btn").on_click(fn() {
    let qty_text = @lib.get_el("restock-qty").get_value()
    let qty = parse_qty(qty_text)
    for item in store.items {
      ignore(@lib.store_restock(store, item.product.id, qty))
    }
    save_state()
    render_products()
  })
  @lib.get_el("reset").on_click(fn() {
    @lib.storage_del(ITEMS_KEY)
    @lib.storage_del(ORDERS_KEY)
    store.items.clear()
    store.orders.clear()
    ignore(@lib.store_import_json(store, catalog_json))
    render_products()
    render_ledger()
  })
}

/// The gate: admin login form when unauthorized, panels + logout when
/// an Admin session resolves.
fn render_gate() -> Unit {
  match @lib.accounts_require(accounts, state.token, 0, @lib.Admin) {
    Some(user) => {
      @lib.get_el("gate").set_html(
        "<div class=\"ok\">管理员 " + user.username +
        " 已登录 <button id=\"logout-btn\">退出</button></div>",
      )
      @lib.get_el("logout-btn").on_click(fn() {
        ignore(@lib.accounts_logout(accounts, state.token))
        state.token = ""
        @lib.storage_del(TOKEN_KEY)
        save_all()
        render_gate()
      })
      render_products()
      render_ledger()
      wire_admin_actions()
      wire_new_product()
    }
    None => {
      @lib.get_el("gate").set_html(
        "<div class=\"login\">管理台需要管理员账号登录（内置演示账号 admin / admin123）<br><input id=\"login-user\" placeholder=\"用户名\"><input id=\"login-pass\" type=\"password\" placeholder=\"密码\"><button id=\"login-btn\">登录</button><div id=\"login-msg\" class=\"hint\"></div></div>",
      )
      @lib.get_el("login-btn").on_click(fn() {
        let user = @lib.get_el("login-user").get_value()
        let pass = @lib.get_el("login-pass").get_value()
        match @lib.accounts_login(accounts, user, pass, 0) {
          Some(session) =>
            match @lib.accounts_require(accounts, session.token, 0, @lib.Admin) {
              Some(_) => {
                state.token = session.token
                @lib.storage_set(TOKEN_KEY, session.token)
                save_all()
                render_gate()
              }
              None =>
                @lib.get_el("login-msg").set_html("该账号不是管理员")
            }
          None => @lib.get_el("login-msg").set_html("用户名或密码错误")
        }
      })
      @lib.get_el("products").set_html("")
      @lib.get_el("ledger").set_html("")
    }
  }
}

/// Create a product from the admin form; auto-generates an id from a
/// content hash when the id box is left empty. Returns "" on success or
/// an error message.
fn create_product_from_form() -> String {
  let name = @lib.get_el("np-name").get_value()
  let name_en = @lib.get_el("np-name-en").get_value()
  let category = @lib.get_el("np-category").get_value()
  let price_text = @lib.get_el("np-price").get_value()
  let stock_text = @lib.get_el("np-stock").get_value()
  let desc = @lib.get_el("np-desc").get_value()
  let image = @lib.get_el("np-image").get_value()
  let mut id_text = @lib.get_el("np-id").get_value()
  if name == "" || category == "" {
    return "名称和类目必填"
  }
  let price = parse_price_cents(price_text)
  if price <= 0 {
    return "价格必须大于 0"
  }
  if id_text == "" {
    id_text = @lib.sha256_hex(name + "|" + category)[0:8].to_owned()
  }
  match @lib.store_find(store, id_text) {
    Some(_) => return "商品 ID 已存在：" + id_text
    None => ()
  }
  let product = match name_en {
    "" =>
      @lib.product_new(id_text, name, category, price, desc=desc, image=image)
    en =>
      @lib.product_new(id_text, name, category, price, name_en=en, desc=desc, image=image)
  }
  @lib.store_add_product(store, product, parse_qty(stock_text))
  save_state()
  ""
}

fn wire_new_product() -> Unit {
  @lib.get_el("np-btn").on_click(fn() {
    let msg = create_product_from_form()
    if msg == "" {
      @lib.get_el("np-msg").set_html("✅ 已上架")
      render_products()
    } else {
      @lib.get_el("np-msg").set_html("❌ " + msg)
    }
  })
}

fn run_admin() -> Unit {
  restore_or_seed()
  let saved_users = @lib.storage_get(USERS_KEY)
  if saved_users != "" {
    ignore(@lib.accounts_import_json(accounts, saved_users))
  } else {
    @lib.accounts_seed_demo(accounts)
    save_all()
  }
  state.token = @lib.storage_get(TOKEN_KEY)
  render_gate()
}
