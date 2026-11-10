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
