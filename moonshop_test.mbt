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
  inspect(shipping, content="800")
  inspect(total, content="3800")
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
      inspect(b.total, content="800") // shipping only
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
