// Checkout: turn a priced cart into an immutable order, deducting stock.

///|
// ---------- order model ----------

/// A snapshot line in a placed order: price captured at purchase time.
#derive(Debug)
pub struct OrderLine {
  product_id : String
  name : String
  unit_price_cents : Int
  qty : Int
}

pub extend OrderLine with @debug.Debug::{to_repr}

/// A placed order with its captured pricing breakdown.
#derive(Debug)
pub struct Order {
  order_no : String
  lines : Array[OrderLine]
  breakdown : PriceBreakdown
}

pub extend Order with @debug.Debug::{to_repr}

///|
// ---------- checkout ----------

// Module-global order sequence for readable order numbers (MO-000001...).
priv struct OrderSeq {
  mut n : Int
}

let order_seq : OrderSeq = { n: 0 }

fn next_order_no() -> String {
  order_seq.n = order_seq.n + 1
  let mut digits = order_seq.n.to_string()
  while digits.length() < 6 {
    digits = "0" + digits
  }
  "MO-" + digits
}

/// Checkout a cart: validates every line against stock, prices the cart,
/// deducts stock and records the order. On any failure (unknown product,
/// insufficient stock) nothing is mutated and None is returned.
pub fn store_checkout(
  store : Store,
  cart : Cart,
  coupon : Coupon?
) -> Order? {
  // validation pass — reject before mutating anything
  for line in cart.lines {
    if !store_in_stock(store, line.product_id, line.qty) {
      return None
    }
  }
  match price_cart(store, cart, coupon) {
    Some(breakdown) => {
      // capture snapshot lines
      let lines : Array[OrderLine] = []
      for line in cart.lines {
        match store_find(store, line.product_id) {
          Some(product) =>
            lines.push(
              {
                product_id: product.id,
                name: product.name,
                unit_price_cents: product.price_cents,
                qty: line.qty,
              },
            )
          None => return None
        }
      }
      // deduct stock (safety net already validated; still checked)
      for line in cart.lines {
        if !store_decrement(store, line.product_id, line.qty) {
          return None
        }
      }
      let order : Order = { order_no: next_order_no(), lines, breakdown }
      store.orders.push(order)
      Some(order)
    }
    None => None
  }
}

/// Look up a placed order by its order number.
pub fn store_find_order(store : Store, order_no : String) -> Order? {
  for order in store.orders {
    if order.order_no == order_no {
      return Some(order)
    }
  }
  None
}

/// All placed orders in placement order.
pub fn store_orders(store : Store) -> Array[Order] {
  store.orders.copy()
}
