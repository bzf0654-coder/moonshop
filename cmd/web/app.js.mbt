// moonshop web demo — the real MoonBit domain engine driving a web page.
// Runs on load (js backend); DOM access via ui.js.mbt externs.

let catalog_json = #|[
                     #|  {"id":"kb-01","name":"Mech Keyboard 87","category":"peripherals","price_cents":49900,"stock":8},
                     #|  {"id":"m-01","name":"Wireless Mouse","category":"peripherals","price_cents":7900,"stock":20},
                     #|  {"id":"sd-01","name":"SSD 1TB NVMe","category":"storage","price_cents":45900,"stock":15},
                     #|  {"id":"hd-01","name":"HDD 4TB","category":"storage","price_cents":59900,"stock":5},
                     #|  {"id":"cam-01","name":"Webcam 2K","category":"meetings","price_cents":32900,"stock":10},
                     #|  {"id":"hub-01","name":"USB-C Hub 7in1","category":"meetings","price_cents":19900,"stock":2}
                     #|]

let store : @lib.Store = @lib.store_new()

let cart : @lib.Cart = @lib.cart_new()

priv struct WebState {
  mut coupon_on : Bool
}

let state : WebState = { coupon_on: true }

fn coupon_now() -> @lib.Coupon? {
  if state.coupon_on {
    Some(@lib.coupon_new("SAVE5000", 5000, 100000))
  } else {
    None
  }
}

///|
// ---------- rendering ----------

fn render_catalog() -> Unit {
  let buf = StringBuilder()
  for item in store.items {
    let p = item.product
    buf.write_string(
      "<div class=\"card\"><div><b>" + p.name +
      "</b><div class=\"cat\">" + p.category +
      " · stock " + item.stock.to_string() +
      "</div></div><div class=\"price\">" + @lib.format_cents(p.price_cents) +
      "</div><button class=\"add\" id=\"add-" + p.id + "\">+ Add to Cart</button></div>",
    )
  }
  get_el("catalog").set_html(buf.to_string())
  for item in store.items {
    let id = item.product.id
    let btn = get_el("add-" + id)
    btn.on_click(fn() {
      ignore(@lib.cart_add(cart, id, 1))
      render_cart()
    })
  }
}

fn cart_qty(id : String) -> Int {
  for line in cart.lines {
    if line.product_id == id {
      return line.qty
    }
  }
  0
}

fn render_cart() -> Unit {
  let buf = StringBuilder()
  if cart.lines.length() == 0 {
    buf.write_string("<div class=\"empty\">The shopping cart is empty</div>")
  } else {
    for line in cart.lines {
      match @lib.store_find(store, line.product_id) {
        Some(p) => {
          buf.write_string(
            "<div class=\"row\"><span>" + p.name + " ×" + line.qty.to_string() +
            "</span><span class=\"price\">" +
            @lib.format_cents(p.price_cents * line.qty) +
            "</span><button class=\"rm\" id=\"rm-" + p.id + "\">−</button></div>",
          )
        }
        None => ()
      }
    }
  }
  // totals preview (only once something is in the cart)
  if cart.lines.length() > 0 {
    append_totals(buf)
  }
  get_el("cart").set_html(buf.to_string())
  for line in cart.lines {
    let id = line.product_id
    let btn = get_el("rm-" + id)
    btn.on_click(fn() {
      let q = cart_qty(id)
      ignore(@lib.cart_set_qty(cart, id, q - 1))
      render_cart()
    })
  }
}

fn append_totals(buf : StringBuilder) -> Unit {
  match @lib.price_cart(store, cart, coupon_now()) {
    Some(b) => {
      let mut coupon_line = ""
      match b.coupon_code {
        Some(code) =>
          coupon_line = "<br/>Coupon " + code + " −" +
          @lib.format_cents(b.coupon_off)
        None => ()
      }
      buf.write_string(
        "<div class=\"sum\">Subtotal " + @lib.format_cents(b.subtotal) +
        (if b.bulk_discount > 0 {
           "<br/>Bulk discount −" + @lib.format_cents(b.bulk_discount)
         } else {
           ""
         }) +
        coupon_line +
        "<br/>Shipping " +
        (if b.shipping == 0 { "free" } else { @lib.format_cents(b.shipping) }) +
        "<br/><b>Total payable " + @lib.format_cents(b.total) + "</b></div>",
      )
    }
    None => buf.write_string("<div class=\"sum\">The cart contains items not in the catalog</div>")
  }
}

fn render_receipt(order : @lib.Order) -> Unit {
  let buf = StringBuilder()
  buf.write_string(
    "<div class=\"ok\">Order placed successfully · " + order.order_no + "</div><table><tr><th>Item</th><th>Qty</th><th>Unit</th><th>Subtotal</th></tr>",
  )
  for line in order.lines {
    buf.write_string(
      "<tr><td>" + line.name + "</td><td>" + line.qty.to_string() +
      "</td><td>" + @lib.format_cents(line.unit_price_cents) +
      "</td><td>" + @lib.format_cents(line.unit_price_cents * line.qty) +
      "</td></tr>",
    )
  }
  let b = order.breakdown
  buf.write_string("</table><div class=\"sum\">")
  buf.write_string("Subtotal " + @lib.format_cents(b.subtotal) + "<br/>")
  if b.bulk_discount > 0 {
    buf.write_string("Bulk discount −" + @lib.format_cents(b.bulk_discount) + "<br/>")
  }
  if b.coupon_off > 0 {
    buf.write_string("Coupon −" + @lib.format_cents(b.coupon_off) + "<br/>")
  }
  buf.write_string(
    "Shipping " +
    (if b.shipping == 0 { "free" } else { @lib.format_cents(b.shipping) }) +
    "<br/><b>Total " + @lib.format_cents(b.total) + "</b></div>",
  )
  get_el("receipt").set_html(buf.to_string())
}

///|
// ---------- entry ----------

fn run() -> Unit {
  ignore(@lib.store_import_json(store, catalog_json))
  render_catalog()
  render_cart()
  get_el("coupon").on_click(fn() {
    state.coupon_on = !state.coupon_on
    get_el("coupon").set_html(
      if state.coupon_on {
        "Coupon SAVE5000 (¥50 off over ¥1000): Enabled"
      } else {
        "Coupon SAVE5000 (¥50 off over ¥1000): Disabled"
      },
    )
    render_cart()
  })
  get_el("checkout").on_click(fn() {
    match @lib.store_checkout(store, cart, coupon_now()) {
      Some(order) => {
        // clear the cart: set every line to zero
        let ids : Array[String] = []
        for line in cart.lines {
          ids.push(line.product_id)
        }
        for id in ids {
          ignore(@lib.cart_set_qty(cart, id, 0))
        }
        render_receipt(order)
        render_catalog()
        render_cart()
      }
      None => get_el("receipt").set_html(
        "<div class=\"fail\">Order failed: insufficient stock, the store was not modified</div>",
      )
    }
  })
}
