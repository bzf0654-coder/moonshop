///|
/// Terminal shopping demo: import catalog from JSON, run a scripted
/// shopping session (browse -> cart -> coupon checkout -> receipt),
/// attempt an over-stock checkout, place a second small order, then
/// export all orders as JSON.
fn main {
  let catalog = #|[
                   #|  {"id":"kb-01","name":"Mech Keyboard 87","category":"peripherals","price_cents":49900,"stock":8},
                   #|  {"id":"m-01","name":"Wireless Mouse","category":"peripherals","price_cents":7900,"stock":20},
                   #|  {"id":"sd-01","name":"SSD 1TB NVMe","category":"storage","price_cents":45900,"stock":15},
                   #|  {"id":"hd-01","name":"HDD 4TB","category":"storage","price_cents":59900,"stock":5},
                   #|  {"id":"cam-01","name":"Webcam 2K","category":"meetings","price_cents":32900,"stock":10},
                   #|  {"id":"hub-01","name":"USB-C Hub 7in1","category":"meetings","price_cents":19900,"stock":2}
                   #|]
  let store = @lib.store_new()
  let imported = @lib.store_import_json(store, catalog)
  println("== [1] catalog imported: " + imported.to_string() + " products ==")
  println("categories: " + @lib.join_strings(@lib.store_categories(store), ", "))
  let found = @lib.store_search(store, "storage")
  let names : Array[String] = []
  for p in found {
    names.push(p.name)
  }
  println("search 'storage': " + @lib.join_strings(names, ", "))

  println("")
  println("== [2] shopping: 2x keyboard + 3x SSD + 1x hub, coupon SAVE5000 ==")
  let cart = @lib.cart_new()
  ignore(@lib.cart_add(cart, "kb-01", 2))
  ignore(@lib.cart_add(cart, "sd-01", 3))
  ignore(@lib.cart_add(cart, "hub-01", 1))
  let coupon = @lib.coupon_new("SAVE5000", 5000, 100000)
  match @lib.store_checkout(store, cart, Some(coupon)) {
    Some(order) => println(@lib.order_receipt(order))
    None => println("checkout failed")
  }

  println("== [3] over-stock attempt: 99x webcam ==")
  let bad = @lib.cart_new()
  ignore(@lib.cart_add(bad, "cam-01", 99))
  match @lib.store_checkout(store, bad, None) {
    Some(_) => println("unexpectedly placed")
    None => println("rejected (insufficient stock), store untouched")
  }

  println("== [4] small order below free-shipping threshold: 1x mouse ==")
  let small = @lib.cart_new()
  ignore(@lib.cart_add(small, "m-01", 1))
  match @lib.store_checkout(store, small, None) {
    Some(order) => println(@lib.order_receipt(order))
    None => println("checkout failed")
  }

  println("== [5] orders exported as JSON ==")
  println(@lib.orders_export_json(store))
}
