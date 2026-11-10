// Checkout: turn a priced cart into an immutable order, deducting stock.

///|
// ---------- order model ----------

/// A snapshot line in a placed order: price and names captured at
/// purchase time (canonical + optional English name for localized
/// receipt re-rendering).
#derive(Debug)
pub struct OrderLine {
  product_id : String
  name : String
  name_en : String?
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
  coupon : Coupon?,
  rebate? : Rebate,
  member_off_pct? : Int,
  now? : Int
) -> Order? {
  // validation pass against *available* stock (on-hand minus active
  // reservations) — reservations block normal checkouts; reject before
  // mutating anything
  for line in cart.lines {
    let tick : Int = match now {
      Some(t) => t
      None => 0
    }
    match store_available(store, line.product_id, tick) {
      Some(avail) =>
        if avail < line.qty {
          return None
        }
      None => return None
    }
  }
  match (match (rebate, member_off_pct) {
    (Some(r), Some(pct)) => price_cart(store, cart, coupon, rebate=r, member_off_pct=pct)
    (Some(r), None) => price_cart(store, cart, coupon, rebate=r)
    (None, Some(pct)) => price_cart(store, cart, coupon, member_off_pct=pct)
    (None, None) => price_cart(store, cart, coupon)
  }) {
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
                name_en: product.name_en,
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

/// Commit a cart that holds `reservation`: the reserved units bypass the
/// availability check (the hold already covers them; the reserved line
/// must not exceed the reserved qty), other lines validate against
/// available stock at `reservation.expires_at`. On success the hold is
/// consumed; on failure it is left untouched.
pub fn store_checkout_reserved(
  store : Store,
  cart : Cart,
  reservation : Reservation,
  coupon : Coupon?,
  rebate? : Rebate,
  member_off_pct? : Int
) -> Order? {
  for line in cart.lines {
    if line.product_id == reservation.product_id {
      if line.qty > reservation.qty {
        return None
      }
    } else {
      match store_available(store, line.product_id, reservation.expires_at) {
        Some(avail) =>
          if avail < line.qty {
            return None
          }
        None => return None
      }
    }
  }
  match (match (rebate, member_off_pct) {
    (Some(r), Some(pct)) => price_cart(store, cart, coupon, rebate=r, member_off_pct=pct)
    (Some(r), None) => price_cart(store, cart, coupon, rebate=r)
    (None, Some(pct)) => price_cart(store, cart, coupon, member_off_pct=pct)
    (None, None) => price_cart(store, cart, coupon)
  }) {
    Some(breakdown) => {
      let lines : Array[OrderLine] = []
      for line in cart.lines {
        match store_find(store, line.product_id) {
          Some(product) =>
            lines.push(
              {
                product_id: product.id,
                name: product.name,
                name_en: product.name_en,
                unit_price_cents: product.price_cents,
                qty: line.qty,
              },
            )
          None => return None
        }
      }
      for line in cart.lines {
        if !store_decrement(store, line.product_id, line.qty) {
          return None
        }
      }
      ignore(store_release(store, reservation.token))
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
