// Placeholder for non-js backends: keeps the executable package valid
// for `moon check` on wasm/wasm-gc/native. Touches @lib so the import
// stays used. The browser demo only supports the js target.
fn run() -> Unit {
  let store = @lib.store_new()
  let cart = @lib.cart_new()
  match @lib.price_cart(store, cart, None) {
    Some(_) => println("moonshop web demo: build with --target js")
    None => println("moonshop web demo: build with --target js")
  }
}
