// Store: the catalog + inventory aggregate every other service operates on.

///|
// ---------- store & inventory ----------

/// A product together with its stock level.
#derive(Debug)
pub struct InventoryItem {
  product : Product
  mut stock : Int
}

pub extend InventoryItem with @debug.Debug::{to_repr}

/// The store aggregate: products with stock, and placed orders.
#derive(Debug)
pub struct Store {
  items : Array[InventoryItem]
  orders : Array[Order]
}

pub extend Store with @debug.Debug::{to_repr}

/// Create an empty store.
pub fn store_new() -> Store {
  { items: [], orders: [] }
}

/// Register a product with an initial stock level.
/// Registering an existing id adds to its stock instead.
pub fn store_add_product(
  store : Store,
  product : Product,
  stock : Int
) -> Unit {
  for item in store.items {
    if item.product.id == product.id {
      item.stock = item.stock + stock
      return
    }
  }
  store.items.push({ product, stock })
}

/// Find a product by id.
pub fn store_find(store : Store, id : String) -> Product? {
  for item in store.items {
    if item.product.id == id {
      return Some(item.product)
    }
  }
  None
}

/// Current stock of a product; None when the product is unknown.
pub fn store_stock(store : Store, id : String) -> Int? {
  for item in store.items {
    if item.product.id == id {
      return Some(item.stock)
    }
  }
  None
}

/// Whether at least `qty` units of the product are in stock.
pub fn store_in_stock(store : Store, id : String, qty : Int) -> Bool {
  match store_stock(store, id) {
    Some(stock) => stock >= qty
    None => false
  }
}

/// Subtract `qty` from a product's stock. Returns false when stock would go
/// negative or the product is unknown. The caller validates first at
/// checkout; this is the safety net.
pub fn store_decrement(store : Store, id : String, qty : Int) -> Bool {
  for item in store.items {
    if item.product.id == id {
      if item.stock >= qty {
        item.stock = item.stock - qty
        return true
      }
      return false
    }
  }
  false
}

/// Case-insensitive substring search across canonical name, English name
/// and category, returning matching products in catalog order.
pub fn store_search(store : Store, text : String) -> Array[Product] {
  let needle = to_lower(text)
  let out : Array[Product] = []
  for item in store.items {
    if contains_ci(item.product.name, needle) ||
      contains_ci_opt(item.product.name_en, needle) ||
      contains_ci(item.product.category, needle) {
      out.push(item.product)
    }
  }
  out
}

/// All distinct categories in first-seen order.
pub fn store_categories(store : Store) -> Array[String] {
  let out : Array[String] = []
  for item in store.items {
    let mut seen = false
    for c in out {
      if c == item.product.category {
        seen = true
        break
      }
    }
    if !seen {
      out.push(item.product.category)
    }
  }
  out
}

// ---------- tiny ascii case helpers (core-only) ----------

/// Join strings with a separator (small helper for displays).
pub fn join_strings(parts : Array[String], sep : String) -> String {
  let buf = StringBuilder()
  for i, part in parts {
    if i > 0 {
      buf.write_string(sep)
    }
    buf.write_string(part)
  }
  buf.to_string()
}

fn to_lower(s : String) -> String {
  let buf = StringBuilder()
  for _, ch in s {
    if ch >= 'A' && ch <= 'Z' {
      match (ch.to_int() + 32).to_char() {
        Some(lower) => buf.write_char(lower)
        None => buf.write_char(ch)
      }
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}

fn contains_ci_opt(s : String?, lower_needle : String) -> Bool {
  match s {
    Some(v) => contains_ci(v, lower_needle)
    None => false
  }
}

fn contains_ci(haystack : String, lower_needle : String) -> Bool {
  if lower_needle == "" {
    return true
  }
  let lower_hay = to_lower(haystack)
  // substring search: try every start offset
  let n = lower_hay.length()
  let m = lower_needle.length()
  if m > n {
    return false
  }
  let offsets = n - m
  for i in 0..<(offsets + 1) {
    let mut match_all = true
    for j in 0..<m {
      if lower_hay[i + j] != lower_needle[j] {
        match_all = false
        break
      }
    }
    if match_all {
      return true
    }
  }
  false
}
