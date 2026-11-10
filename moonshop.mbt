// moonshop — a minimal e-commerce domain engine in MoonBit.
//
// All money values are Int cents (分) to avoid floating point drift.
// The core is a pure in-memory domain layer (catalog / cart / pricing /
// checkout / orders) with JSON persistence; an HTTP layer is roadmap.

///|
// ---------- domain model ----------

/// A product SKU. `price_cents` is the unit price in cents (分).
/// `name` is the canonical (default-locale) name; `name_en` carries the
/// optional English translation used by localized storefronts.
#derive(Debug)
pub struct Product {
  id : String
  name : String
  name_en : String?
  category : String
  price_cents : Int
  desc : String
  image : String
}

pub extend Product with @debug.Debug::{to_repr}

/// Construct a product (id, name, category, unit price in cents).
/// `name_en` is an optional English translation of the product name.
pub fn product_new(
  id : String,
  name : String,
  category : String,
  price_cents : Int,
  name_en? : String,
  desc? : String,
  image? : String
) -> Product {
  let d = match desc {
    Some(v) => v
    None => ""
  }
  let img = match image {
    Some(v) => v
    None => ""
  }
  { id, name, name_en, category, price_cents, desc: d, image: img }
}

/// One line in a shopping cart: `qty` units of a product.
#derive(Debug)
pub struct CartLine {
  product_id : String
  mut qty : Int
}

pub extend CartLine with @debug.Debug::{to_repr}

/// A shopping cart keeps insertion order; quantities of the same product
/// merge into one line.
#derive(Debug)
pub struct Cart {
  lines : Array[CartLine]
}

pub extend Cart with @debug.Debug::{to_repr}

///|
// ---------- cart operations ----------

/// Create an empty cart.
pub fn cart_new() -> Cart {
  { lines: [] }
}

/// Add `qty` units of `product_id`. Adding an existing product merges into
/// its line. Returns false when `qty` is not positive.
pub fn cart_add(cart : Cart, product_id : String, qty : Int) -> Bool {
  if qty <= 0 {
    return false
  }
  for line in cart.lines {
    if line.product_id == product_id {
      line.qty = line.qty + qty
      return true
    }
  }
  cart.lines.push({ product_id, qty })
  true
}

/// Set the quantity of `product_id` to exactly `qty`.
/// Setting to 0 removes the line. Returns false when `qty` is negative
/// or the product is not in the cart.
pub fn cart_set_qty(cart : Cart, product_id : String, qty : Int) -> Bool {
  if qty < 0 {
    return false
  }
  for i, line in cart.lines {
    if line.product_id == product_id {
      if qty == 0 {
        ignore(cart.lines.remove(i)) // remove returns the removed element
      } else {
        line.qty = qty
      }
      return true
    }
  }
  false
}

/// Remove a product line entirely. Returns false if it was not in the cart.
pub fn cart_remove(cart : Cart, product_id : String) -> Bool {
  cart_set_qty(cart, product_id, 0)
}

/// Total number of units across all lines.
pub fn cart_total_qty(cart : Cart) -> Int {
  let mut total = 0
  for line in cart.lines {
    total = total + line.qty
  }
  total
}

/// Whether the cart has no lines.
pub fn cart_is_empty(cart : Cart) -> Bool {
  cart.lines.length() == 0
}
