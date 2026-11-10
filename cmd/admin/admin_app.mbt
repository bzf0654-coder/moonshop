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

const ITEMS_KEY : String = "moonshop.items"

const ORDERS_KEY : String = "moonshop.orders"

fn save_state() -> Unit {
  @lib.storage_set(ITEMS_KEY, @lib.catalog_export_json(store))
  @lib.storage_set(ORDERS_KEY, @lib.orders_export_json(store))
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
      "<tr><td>" + p.name + "<div class=\"sub\">" + p.id + " · " +
      p.category + "</div></td><td class=\"num\" id=\"stock-" + p.id + "\">" +
      item.stock.to_string() + low +
      "</td><td class=\"num\">" + @lib.format_cents(p.price_cents) +
      "</td><td class=\"num\"><button class=\"rs\" id=\"rs-" + p.id +
      "\">补货</button></td></tr>",
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
fn run_admin() -> Unit {
  restore_or_seed()
  render_products()
  render_ledger()
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
