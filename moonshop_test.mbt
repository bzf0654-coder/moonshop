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
