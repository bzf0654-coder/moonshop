// Placeholder for non-js backends: the HTTP API needs the Node host.
// Touches @lib so the import stays used on every target.
fn run_server() -> Unit {
  let store = @lib.store_new()
  let cart = @lib.cart_new()
  match @lib.price_cart(store, cart, None) {
    Some(_) => println("moonshop API server: build with --target js and run with node")
    None => println("moonshop API server: build with --target js and run with node")
  }
}
