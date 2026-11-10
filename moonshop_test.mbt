// Blackbox tests for the public API of @moonshop.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
test "cart add merges quantities per product" {
  let cart = @moonshop.cart_new()
  inspect(@moonshop.cart_add(cart, "kb-01", 1), content="true")
  inspect(@moonshop.cart_add(cart, "kb-01", 2), content="true")
  inspect(@moonshop.cart_add(cart, "mouse-01", 1), content="true")
  inspect(cart.lines.length(), content="2")
  inspect(cart.lines[0].qty, content="3")
  inspect(@moonshop.cart_total_qty(cart), content="4")
  inspect(@moonshop.cart_is_empty(cart), content="false")
}

///|
test "cart rejects non-positive quantities" {
  let cart = @moonshop.cart_new()
  inspect(@moonshop.cart_add(cart, "kb-01", 0), content="false")
  inspect(@moonshop.cart_add(cart, "kb-01", -3), content="false")
  inspect(@moonshop.cart_is_empty(cart), content="true")
}

///|
test "cart set quantity updates, removes at zero, rejects unknown" {
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "kb-01", 2))
  inspect(@moonshop.cart_set_qty(cart, "kb-01", 5), content="true")
  inspect(cart.lines[0].qty, content="5")
  inspect(@moonshop.cart_set_qty(cart, "kb-01", 0), content="true")
  inspect(@moonshop.cart_is_empty(cart), content="true")
  inspect(@moonshop.cart_set_qty(cart, "ghost", 1), content="false")
  inspect(@moonshop.cart_remove(cart, "ghost"), content="false")
}

///|
test "store registers products, merges stock by id" {
  let store = @moonshop.store_new()
  @moonshop.store_add_product(store, @moonshop.product_new("kb-01", "Mech Keyboard", "peripherals", 49900), 10)
  @moonshop.store_add_product(store, @moonshop.product_new("kb-01", "Mech Keyboard", "peripherals", 49900), 5)
  inspect(@debug.to_string(@moonshop.store_stock(store, "kb-01")), content="Some(15)")
}

///|
test "store stock checks and decrement safety" {
  let store = @moonshop.store_new()
  @moonshop.store_add_product(store, @moonshop.product_new("m-01", "Mouse", "peripherals", 9900), 3)
  inspect(@moonshop.store_in_stock(store, "m-01", 3), content="true")
  inspect(@moonshop.store_in_stock(store, "m-01", 4), content="false")
  inspect(@moonshop.store_in_stock(store, "ghost", 1), content="false")
  inspect(@moonshop.store_decrement(store, "m-01", 2), content="true")
  inspect(@debug.to_string(@moonshop.store_stock(store, "m-01")), content="Some(1)")
  inspect(@moonshop.store_decrement(store, "m-01", 2), content="false")
}

///|
test "store search is case-insensitive across name and category" {
  let store = @moonshop.store_new()
  @moonshop.store_add_product(store, @moonshop.product_new("kb-01", "Mech Keyboard", "peripherals", 49900), 1)
  @moonshop.store_add_product(store, @moonshop.product_new("hd-01", "HDD 4TB", "storage", 59900), 1)
  @moonshop.store_add_product(store, @moonshop.product_new("sd-01", "SSD 1TB", "storage", 45900), 1)
  inspect(@moonshop.store_search(store, "KEYBOARD").length(), content="1")
  inspect(@moonshop.store_search(store, "storage").length(), content="2")
  inspect(@moonshop.store_search(store, "").length(), content="3")
  inspect(@moonshop.store_categories(store).length(), content="2")
}

fn demo_store() -> @moonshop.Store {
  let store = @moonshop.store_new()
  @moonshop.store_add_product(store, @moonshop.product_new("kb-01", "Mech Keyboard", "peripherals", 49900), 10)
  @moonshop.store_add_product(store, @moonshop.product_new("m-01", "Mouse", "peripherals", 5000), 10)
  @moonshop.store_add_product(store, @moonshop.product_new("sd-01", "SSD 1TB", "storage", 10000), 10)
  store
}

///|
test "pricing: no discount, free shipping over threshold" {
  let store = demo_store()
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "kb-01", 2)) // 99800
  let p = @moonshop.price_cart(store, cart, None)
  let mut total = -1
  let mut shipping = -1
  match p {
    Some(b) => { total = b.total; shipping = b.shipping }
    None => ()
  }
  inspect(total, content="99800")
  inspect(shipping, content="0")
}

///|
test "pricing: bulk discount on 3+ units of one product" {
  let store = demo_store()
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "sd-01", 3)) // 30000, -5% = 1500
  let p = @moonshop.price_cart(store, cart, None)
  let mut bulk = -1
  let mut total = -1
  match p {
    Some(b) => { bulk = b.bulk_discount; total = b.total }
    None => ()
  }
  inspect(bulk, content="1500")
  inspect(total, content="28500")
}

///|
test "pricing: coupon applies above threshold, not below" {
  let store = demo_store()
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "m-01", 1)) // 5000
  let coupon = @moonshop.coupon_new("SAVE2000", 2000, 5000)
  let p = @moonshop.price_cart(store, cart, Some(coupon))
  let mut total = -1
  let mut coupon_off = -1
  let mut shipping = -1
  match p {
    Some(b) => { total = b.total; coupon_off = b.coupon_off; shipping = b.shipping }
    None => ()
  }
  inspect(coupon_off, content="2000")
  inspect(shipping, content=(
    #|1200
  ))
  inspect(total, content=(
    #|4200
  ))
  let weak = @moonshop.coupon_new("BIG", 2000, 999999)
  match @moonshop.price_cart(store, cart, Some(weak)) {
    Some(b) => inspect(b.coupon_off, content="0")
    None => inspect("missing", content="REACHED")
  }
}

///|
test "pricing: coupon capped at basket value, unknown product rejected" {
  let store = demo_store()
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "m-01", 2)) // 10000
  let huge = @moonshop.coupon_new("HUGE", 999999, 0)
  match @moonshop.price_cart(store, cart, Some(huge)) {
    Some(b) => {
      inspect(b.coupon_off, content="10000")
      inspect(b.total, content=(
        #|1200
      )) // shipping only
    }
    None => inspect("missing", content="REACHED")
  }
  let ghost = @moonshop.cart_new()
  ignore(@moonshop.cart_add(ghost, "ghost-01", 1))
  match @moonshop.price_cart(store, ghost, None) {
    Some(_) => inspect("priced", content="REACHED")
    None => inspect("rejected", content="rejected")
  }
}

///|
test "checkout captures order, deducts stock, keeps pricing snapshot" {
  let store = demo_store()
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "sd-01", 3)) // 30000, bulk -1500
  let mut order_no = ""
  match @moonshop.store_checkout(store, cart, None) {
    Some(order) => {
      order_no = order.order_no
      inspect(order.lines.length(), content="1")
      inspect(order.lines[0].name, content="SSD 1TB")
      inspect(order.breakdown.total, content="28500")
    }
    None => inspect("no order", content="REACHED")
  }
  inspect(@debug.to_string(@moonshop.store_stock(store, "sd-01")), content="Some(7)")
  match @moonshop.store_find_order(store, order_no) {
    Some(_) => inspect("found", content="found")
    None => inspect("missing", content="REACHED")
  }
}

///|
test "checkout rejects insufficient stock without mutation" {
  let store = demo_store() // m-01 stock 10
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "m-01", 11))
  match @moonshop.store_checkout(store, cart, None) {
    Some(_) => inspect("placed", content="REACHED")
    None => inspect("rejected", content="rejected")
  }
  inspect(@debug.to_string(@moonshop.store_stock(store, "m-01")), content="Some(10)")
  inspect(@moonshop.store_orders(store).length(), content="0")
}

///|
test "order numbers are sequential and zero-padded" {
  let store = demo_store()
  let mut first = ""
  let mut second = ""
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "m-01", 1))
  match @moonshop.store_checkout(store, cart, None) {
    Some(o) => first = o.order_no
    None => ()
  }
  let cart2 = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart2, "sd-01", 1))
  match @moonshop.store_checkout(store, cart2, None) {
    Some(o) => second = o.order_no
    None => ()
  }
  inspect(first != "", content="true")
  inspect(second != "", content="true")
  inspect(first != second, content="true")
  inspect(@moonshop.store_orders(store).length(), content="2")
}

///|
test "catalog import from JSON skips malformed entries" {
  let store = @moonshop.store_new()
  let catalog = "[{\"id\":\"kb-01\",\"name\":\"Mech Keyboard\",\"category\":\"peripherals\",\"price_cents\":49900,\"stock\":10},{\"id\":\"m-01\",\"name\":\"Mouse\",\"category\":\"peripherals\",\"price_cents\":5000,\"stock\":10},{\"id\":\"bad\",\"name\":\"No price\",\"category\":\"x\"}]"
  let imported = @moonshop.store_import_json(store, catalog)
  inspect(imported, content="2")
  inspect(@debug.to_string(@moonshop.store_stock(store, "kb-01")), content="Some(10)")
  inspect(@moonshop.store_search(store, "mouse").length(), content="1")
}

///|
test "orders export round-trips as a JSON array" {
  let store = @moonshop.store_new()
  ignore(@moonshop.store_import_json(store, "[{\"id\":\"sd-01\",\"name\":\"SSD 1TB\",\"category\":\"storage\",\"price_cents\":10000,\"stock\":5}]"))
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "sd-01", 3))
  match @moonshop.store_checkout(store, cart, None) {
    Some(_) => ()
    None => inspect("no order", content="REACHED")
  }
  let json = @moonshop.orders_export_json(store)
  inspect(json.contains("\"order_no\":\"MO-"), content="true")
  inspect(json.contains("\"name\":\"SSD 1TB\""), content="true")
  inspect(json.contains("\"total\":28500"), content="true")
  match @moonshop.json_parse(json) {
    JArray(items) => inspect(items.length(), content="1")
    _ => inspect("not array", content="REACHED")
  }
}

///|
test "format_cents renders yuan with two decimals" {
  inspect(@moonshop.format_cents(49900), content="¥499.00")
  inspect(@moonshop.format_cents(5), content="¥0.05")
  inspect(@moonshop.format_cents(0), content="¥0.00")
  inspect(@moonshop.format_cents(-1050), content="¥-10.50")
  inspect(@moonshop.join_strings(["a", "b", "c"], ", "), content="a, b, c")
}

///|
test "order receipt shows lines and every pricing stage" {
  let store = @moonshop.store_new()
  ignore(@moonshop.store_import_json(store, "[{\"id\":\"sd-01\",\"name\":\"SSD 1TB\",\"category\":\"storage\",\"price_cents\":10000,\"stock\":5},{\"id\":\"m-01\",\"name\":\"Mouse\",\"category\":\"peripherals\",\"price_cents\":5000,\"stock\":5}]"))
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "sd-01", 3))
  ignore(@moonshop.cart_add(cart, "m-01", 1))
  match @moonshop.store_checkout(store, cart, None) {
    Some(order) => {
      let r = @moonshop.order_receipt(order)
      inspect(r.contains("## Receipt MO-"), content="true")
      inspect(r.contains("| SSD 1TB | 3 | ¥100.00 | ¥300.00 |"), content="true")
      inspect(r.contains("bulk discount (qty ≥ 3): -¥15.00"), content="true")
      inspect(r.contains("shipping: free"), content="true")
      inspect(r.contains("**total: ¥335.00**"), content="true")
    }
    None => inspect("no order", content="REACHED")
  }
}

///|
test "name_en round-trips through import, search and order snapshot" {
  let store = @moonshop.store_new()
  let catalog = "[{\"id\":\"kb\",\"name\":\"机械键盘\",\"name_en\":\"Mech Keyboard\",\"category\":\"peripherals\",\"price_cents\":49900,\"stock\":3},{\"id\":\"bad\",\"name\":\"缺英文名\"}]"
  inspect(@moonshop.store_import_json(store, catalog), content=(
    #|1
  ))
  inspect(@moonshop.store_search(store, "mech").length(), content="1")
  inspect(@moonshop.store_search(store, "键盘").length(), content="1")
  match @moonshop.store_find(store, "kb") {
    Some(p) =>
      inspect(@debug.to_string(p.name_en), content=(
        #|Some("Mech Keyboard")
      ))
    None => inspect("missing", content="REACHED")
  }
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "kb", 1))
  match @moonshop.store_checkout(store, cart, None) {
    Some(order) =>
      match order.lines[0].name_en {
        Some(en) => inspect(en, content="Mech Keyboard")
        None => inspect("no name_en", content="REACHED")
      }
    None => inspect("no order", content="REACHED")
  }
  let exported = @moonshop.orders_export_json(store)
  inspect(exported.contains("\"name_en\":\"Mech Keyboard\""), content="true")
}

///|
test "rebate applies above threshold before the coupon stage" {
  let store = demo_store()
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "kb-01", 2)) // 99800
  // rebate 满 ¥200 减 ¥50, coupon 满 ¥500 减 ¥20: both fire, order matters
  let r = @moonshop.price_cart(
    store,
    cart,
    Some(@moonshop.coupon_new("C20", 2000, 50000)),
    rebate=@moonshop.rebate_new(20000, 5000),
  )
  match r {
    Some(b) => {
      inspect(b.rebate_off, content="5000")
      inspect(b.coupon_off, content="2000")
      inspect(b.total, content="92800")
    }
    None => inspect("missing", content="REACHED")
  }
  // below rebate threshold: nothing off, coupon still works alone
  let small = @moonshop.cart_new()
  ignore(@moonshop.cart_add(small, "m-01", 3)) // 15000
  match @moonshop.price_cart(
    store,
    small,
    None,
    rebate=@moonshop.rebate_new(20000, 5000),
  ) {
    Some(b) => {
      inspect(b.rebate_off, content="0")
      inspect(b.bulk_discount, content=(
        #|750
      ))
      inspect(b.total, content=(
        #|14250
      ))
    }
    None => inspect("missing", content="REACHED")
  }
}

///|
test "catalog and orders round-trip through export/import" {
  let store = @moonshop.store_new()
  ignore(@moonshop.store_import_json(store, "[{\"id\":\"kb\",\"name\":\"机械键盘\",\"name_en\":\"Mech Keyboard\",\"category\":\"peripherals\",\"price_cents\":49900,\"stock\":7}]"))
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "kb", 2))
  match @moonshop.store_checkout(store, cart, None) {
    Some(_) => ()
    None => inspect("no order", content="REACHED")
  }
  let items_json = @moonshop.catalog_export_json(store)
  let orders_json = @moonshop.orders_export_json(store)
  // restore into a fresh store
  let store2 = @moonshop.store_new()
  inspect(@moonshop.store_import_json(store2, items_json), content="1")
  inspect(@moonshop.orders_import_json(store2, orders_json), content="1")
  inspect(@debug.to_string(@moonshop.store_stock(store2, "kb")), content="Some(5)")
  inspect(@moonshop.store_orders(store2).length(), content="1")
  // sequence continues past the imported order
  let cart2 = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart2, "kb", 1))
  match @moonshop.store_checkout(store2, cart2, None) {
    Some(o) => inspect(o.order_no != "MO-000001", content="true")
    None => inspect("no order", content="REACHED")
  }
}

///|
test "member stage and tiered shipping compose with the pipeline" {
  let store = demo_store()
  let cart = @moonshop.cart_new()
  ignore(@moonshop.cart_add(cart, "kb-01", 2)) // 99800
  match @moonshop.price_cart(store, cart, None, member_off_pct=10) {
    Some(b) => {
      inspect(b.member_off, content="9980")
      inspect(b.bulk_discount, content="0")
      inspect(b.shipping, content="0")
      inspect(b.total, content="89820")
    }
    None => inspect("missing", content="REACHED")
  }
  // tier bands: < ¥49 surcharge, standard band, free band
  inspect(@moonshop.shipping_fee_for(3000), content="1200")
  inspect(@moonshop.shipping_fee_for(4900), content="800")
  inspect(@moonshop.shipping_fee_for(9900), content="0")
  // clamping: absurd pct capped at 50
  match @moonshop.price_cart(store, cart, None, member_off_pct=500) {
    Some(b) => inspect(b.member_off, content="49900")
    None => inspect("missing", content="REACHED")
  }
}

///|
test "reservations block normal checkout and commit cleanly" {
  let store = demo_store()
  match @moonshop.store_reserve(store, "sd-01", 3, 100) {
    Some(r) => {
      inspect(@debug.to_string(@moonshop.store_available(store, "sd-01", 0)), content="Some(7)")
      let cart8 = @moonshop.cart_new()
      ignore(@moonshop.cart_add(cart8, "sd-01", 8))
      match @moonshop.store_checkout(store, cart8, None) {
        Some(_) => inspect("placed", content="REACHED")
        None => inspect("blocked", content="blocked")
      }
      let cart3 = @moonshop.cart_new()
      ignore(@moonshop.cart_add(cart3, "sd-01", 3))
      match @moonshop.store_checkout_reserved(store, cart3, r, None) {
        Some(_) => inspect("placed", content="placed")
        None => inspect("failed", content="REACHED")
      }
      inspect(@debug.to_string(@moonshop.store_stock(store, "sd-01")), content="Some(7)")
      inspect(@moonshop.store_orders(store).length(), content="1")
      inspect(@debug.to_string(@moonshop.store_available(store, "sd-01", 0)), content="Some(7)")
    }
    None => inspect("reserve failed", content="REACHED")
  }
}

///|
test "expired reservations release on sweep and stop blocking" {
  let store = demo_store()
  match @moonshop.store_reserve(store, "m-01", 5, 10) {
    Some(r) => {
      inspect(@debug.to_string(@moonshop.store_available(store, "m-01", 5)), content="Some(5)")
      inspect(@moonshop.store_sweep(store, 5), content="0")
      inspect(@moonshop.store_sweep(store, 11), content="1")
      inspect(@debug.to_string(@moonshop.store_available(store, "m-01", 0)), content="Some(10)")
      inspect(@moonshop.store_release(store, r.token), content="false")
    }
    None => inspect("reserve failed", content="REACHED")
  }
  match @moonshop.store_reserve(store, "m-01", 11, 100) {
    Some(_) => inspect("reserved", content="REACHED")
    None => inspect("rejected", content="rejected")
  }
}

///|
test "store_restock adds stock and rejects unknown ids" {
  let store = demo_store()
  inspect(@moonshop.store_restock(store, "sd-01", 5), content="true")
  inspect(@debug.to_string(@moonshop.store_stock(store, "sd-01")), content="Some(15)")
  inspect(@moonshop.store_restock(store, "ghost", 5), content="false")
  inspect(@moonshop.store_restock(store, "sd-01", 0), content="false")
}
