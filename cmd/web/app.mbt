// moonshop web demo — the real MoonBit domain engine driving a web page.
// Bilingual (中文/English) with a live toggle; all UI strings come from
// the MoonBit side, so the page keeps zero business JavaScript.

let catalog_json = #|[
                     #|  {"id":"kb-01","name":"机械键盘 87键","name_en":"Mech Keyboard 87","category":"peripherals","price_cents":49900,"stock":8},
                     #|  {"id":"m-01","name":"无线鼠标","name_en":"Wireless Mouse","category":"peripherals","price_cents":7900,"stock":20},
                     #|  {"id":"sd-01","name":"固态硬盘 1TB","name_en":"SSD 1TB NVMe","category":"storage","price_cents":45900,"stock":15},
                     #|  {"id":"hd-01","name":"机械硬盘 4TB","name_en":"HDD 4TB","category":"storage","price_cents":59900,"stock":5},
                     #|  {"id":"cam-01","name":"高清摄像头 2K","name_en":"Webcam 2K","category":"meetings","price_cents":32900,"stock":10},
                     #|  {"id":"hub-01","name":"七合一扩展坞","name_en":"USB-C Hub 7in1","category":"meetings","price_cents":19900,"stock":2}
                     #|]

let store : @lib.Store = @lib.store_new()

let cart : @lib.Cart = @lib.cart_new()

priv struct WebState {
  mut coupon_on : Bool
  mut rebate_on : Bool
  mut zh : Bool
  mut last_order : @lib.Order?
}

let state : WebState = { coupon_on: true, rebate_on: true, zh: true, last_order: None }

/// Current-language text picker.
fn t(zh : String, en : String) -> String {
  if state.zh {
    zh
  } else {
    en
  }
}

/// Known categories get localized labels; unknown ones pass through.
fn category_label(c : String) -> String {
  if state.zh {
    match c {
      "peripherals" => "外设"
      "storage" => "存储"
      "meetings" => "会议设备"
      other => other
    }
  } else {
    c
  }
}

/// Localized product name: English mode prefers `name_en`, falling back
/// to the canonical name; Chinese mode shows the canonical name.
fn product_name(p : @lib.Product) -> String {
  if !state.zh {
    match p.name_en {
      Some(en) => return en
      None => ()
    }
  }
  p.name
}

/// Localized name of an order snapshot line (same rule as product_name).
fn line_name(l : @lib.OrderLine) -> String {
  if !state.zh {
    match l.name_en {
      Some(en) => return en
      None => ()
    }
  }
  l.name
}

fn coupon_now() -> @lib.Coupon? {
  if state.coupon_on {
    Some(@lib.coupon_new("SAVE5000", 5000, 100000))
  } else {
    None
  }
}

fn rebate_now() -> @lib.Rebate? {
  if state.rebate_on {
    Some(@lib.rebate_new(30000, 3000))
  } else {
    None
  }
}

///|
// ---------- localStorage persistence ----------

const ITEMS_KEY : String = "moonshop.items"

const ORDERS_KEY : String = "moonshop.orders"

fn save_state() -> Unit {
  storage_set(ITEMS_KEY, @lib.catalog_export_json(store))
  storage_set(ORDERS_KEY, @lib.orders_export_json(store))
}

/// Restore catalog + order history saved by a previous session; falls
/// back to the built-in demo catalog on first run.
fn restore_or_seed() -> Unit {
  let saved_items = storage_get(ITEMS_KEY)
  if saved_items != "" {
    ignore(@lib.store_import_json(store, saved_items))
    let saved_orders = storage_get(ORDERS_KEY)
    if saved_orders != "" {
      ignore(@lib.orders_import_json(store, saved_orders))
    }
  } else {
    ignore(@lib.store_import_json(store, catalog_json))
  }
}

fn reset_demo() -> Unit {
  storage_del(ITEMS_KEY)
  storage_del(ORDERS_KEY)
  store.items.clear()
  store.orders.clear()
  state.coupon_on = true
  state.rebate_on = true
  state.last_order = None
  ignore(@lib.store_import_json(store, catalog_json))
}

///|
// ---------- rendering ----------

fn render_coupon_label() -> Unit {
  let status = if state.coupon_on {
    t("已启用", "ON")
  } else {
    t("已停用", "OFF")
  }
  get_el("coupon").set_html(
    t(
      "优惠券 SAVE5000（满 ¥1000 减 ¥50）：" + status,
      "Coupon SAVE5000 (¥50 off over ¥1000): " + status,
    ),
  )
  let rstatus = if state.rebate_on {
    t("参加中", "joined")
  } else {
    t("未参加", "off")
  }
  get_el("rebate").set_html(
    t(
      "满减活动（满 ¥300 减 ¥30）：" + rstatus,
      "Rebate (¥30 off over ¥300): " + rstatus,
    ),
  )
}

/// Static shell texts (headings, buttons, subtitle) — re-rendered by
/// MoonBit so the language toggle covers the whole page.
fn render_shell() -> Unit {
  get_el("subtitle").set_html(
    t(
      "纯 MoonBit 电商领域引擎（目录 / 库存 / 定价 / 结账 / 订单）——本页业务逻辑零 JavaScript。",
      "A pure-MoonBit e-commerce domain engine (catalog / inventory / pricing / checkout / orders) — zero business JavaScript on this page.",
    ),
  )
  get_el("h-catalog").set_html(t("商品目录", "Catalog"))
  get_el("h-cart").set_html(t("购物车", "Shopping Cart"))
  get_el("h-receipt").set_html(t("订单小票", "Receipt"))
  get_el("checkout").set_html(t("结账 Checkout", "Checkout"))
  get_el("lang").set_html(if state.zh { "EN" } else { "中文" })
  render_coupon_label()
}

fn render_catalog() -> Unit {
  let buf = StringBuilder()
  for item in store.items {
    let p = item.product
    buf.write_string(
      "<div class=\"card\"><div><b>" + product_name(p) +
      "</b><div class=\"cat\">" + category_label(p.category) +
      " · " + t("库存", "stock") + " " + item.stock.to_string() +
      (if item.stock <= 3 {
         "<span class=\"low\"> · " + t("仅剩", "only") + " " + item.stock.to_string() + "</span>"
       } else {
         ""
       }) +
      "</div></div><div class=\"price\">" + @lib.format_cents(p.price_cents) +
      "</div><button class=\"add\" id=\"add-" + p.id + "\">" +
      t("+ 加入购物车", "+ Add to Cart") + "</button></div>",
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

fn append_totals(buf : StringBuilder) -> Unit {
  match @lib.price_cart(store, cart, coupon_now()) {
    Some(b) => {
      let mut coupon_line = ""
      match b.coupon_code {
        Some(code) =>
          coupon_line = "<br/>" + t("优惠券", "Coupon") + " " + code + " −" +
          @lib.format_cents(b.coupon_off)
        None => ()
      }
      buf.write_string(
        "<div class=\"sum\">" + t("小计", "Subtotal") + " " +
        @lib.format_cents(b.subtotal) +
        (if b.bulk_discount > 0 {
           "<br/>" + t("批发折扣", "Bulk discount") + " −" +
           @lib.format_cents(b.bulk_discount)
         } else {
           ""
         }) +
        (if b.rebate_off > 0 {
           "<br/>" + t("满减", "Rebate") + " −" +
           @lib.format_cents(b.rebate_off)
         } else {
           ""
         }) +
        coupon_line +
        "<br/>" + t("运费", "Shipping") + " " +
        (if b.shipping == 0 {
           t("免邮", "free")
         } else {
           @lib.format_cents(b.shipping)
         }) +
        "<br/><b>" + t("应付合计", "Total payable") + " " +
        @lib.format_cents(b.total) + "</b></div>",
      )
    }
    None => buf.write_string(
      "<div class=\"sum\">" +
      t("购物车包含目录中不存在的商品", "The cart contains items not in the catalog") +
      "</div>",
    )
  }
}

fn render_cart() -> Unit {
  let buf = StringBuilder()
  if cart.lines.length() == 0 {
    buf.write_string(
      "<div class=\"empty\">" +
      t("购物车是空的", "The shopping cart is empty") +
      "</div>",
    )
  } else {
    for line in cart.lines {
      match @lib.store_find(store, line.product_id) {
        Some(p) => {
          buf.write_string(
            "<div class=\"row\"><span>" + product_name(p) + " ×" + line.qty.to_string() +
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

fn render_receipt(order : @lib.Order) -> Unit {
  let buf = StringBuilder()
  buf.write_string(
    "<div class=\"ok\">" + t("下单成功", "Order placed") + " · " +
    order.order_no + "</div><table><tr><th>" + t("商品", "Item") + "</th><th>" +
    t("数量", "Qty") + "</th><th>" + t("单价", "Unit") + "</th><th>" +
    t("小计", "Subtotal") + "</th></tr>",
  )
  for line in order.lines {
    buf.write_string(
      "<tr><td>" + line_name(line) + "</td><td>" + line.qty.to_string() +
      "</td><td>" + @lib.format_cents(line.unit_price_cents) +
      "</td><td>" + @lib.format_cents(line.unit_price_cents * line.qty) +
      "</td></tr>",
    )
  }
  let b = order.breakdown
  buf.write_string("</table><div class=\"sum\">")
  buf.write_string(t("小计", "Subtotal") + " " + @lib.format_cents(b.subtotal) + "<br/>")
  if b.bulk_discount > 0 {
    buf.write_string(
      t("批发折扣", "Bulk discount") + " −" +
      @lib.format_cents(b.bulk_discount) + "<br/>",
    )
  }
  if b.rebate_off > 0 {
    buf.write_string(
      t("满减", "Rebate") + " −" + @lib.format_cents(b.rebate_off) + "<br/>",
    )
  }
  if b.coupon_off > 0 {
    buf.write_string(
      t("优惠券", "Coupon") + " −" + @lib.format_cents(b.coupon_off) + "<br/>",
    )
  }
  buf.write_string(
    t("运费", "Shipping") + " " +
    (if b.shipping == 0 {
       t("免邮", "free")
     } else {
       @lib.format_cents(b.shipping)
     }) +
    "<br/><b>" + t("合计", "Total") + " " + @lib.format_cents(b.total) +
    "</b></div>",
  )
  get_el("receipt").set_html(buf.to_string())
}

fn render_receipt_view() -> Unit {
  match state.last_order {
    Some(order) => render_receipt(order)
    None => get_el("receipt").set_html(
      "<div class=\"empty\">" +
      t("下单后这里显示小票", "The receipt appears here after checkout") +
      "</div>",
    )
  }
}

///|
// ---------- entry ----------

fn run() -> Unit {
  restore_or_seed()
  // replay the most recent order into the receipt panel after a restore
  let n = store.orders.length()
  if n > 0 {
    state.last_order = Some(store.orders[n - 1])
  }
  render_shell()
  render_catalog()
  render_cart()
  render_receipt_view()
  get_el("lang").on_click(fn() {
    state.zh = !state.zh
    render_shell()
    render_catalog()
    render_cart()
    render_receipt_view()
  })
  get_el("reset").on_click(fn() {
    reset_demo()
    render_shell()
    render_catalog()
    render_cart()
    render_receipt_view()
  })
  get_el("coupon").on_click(fn() {
    state.coupon_on = !state.coupon_on
    render_coupon_label()
    render_cart()
  })
  get_el("rebate").on_click(fn() {
    state.rebate_on = !state.rebate_on
    render_coupon_label()
    render_cart()
  })
  get_el("checkout").on_click(fn() {
    let placed = match rebate_now() {
      Some(r) => @lib.store_checkout(store, cart, coupon_now(), rebate=r)
      None => @lib.store_checkout(store, cart, coupon_now())
    }
    match placed {
      Some(order) => {
        // clear the cart: set every line to zero
        let ids : Array[String] = []
        for line in cart.lines {
          ids.push(line.product_id)
        }
        for id in ids {
          ignore(@lib.cart_set_qty(cart, id, 0))
        }
        state.last_order = Some(order)
        save_state()
        render_receipt_view()
        render_catalog()
        render_cart()
      }
      None => get_el("receipt").set_html(
        "<div class=\"fail\">" +
        t(
          "下单失败：库存不足，商店未被修改",
          "Checkout failed: insufficient stock, the store was not modified"
        ) +
        "</div>",
      )
    }
  })
}
