// Placeholder for non-js/wasm-gc backends. Touches @lib so the import
// stays used on every target.
fn run_admin() -> Unit {
  let store = @lib.store_new()
  let cart = @lib.cart_new()
  match @lib.price_cart(store, cart, None) {
    Some(_) => println("moonshop admin: build with --target js or wasm-gc")
    None => println("moonshop admin: build with --target js or wasm-gc")
  }
}
