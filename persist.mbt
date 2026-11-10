// JSON persistence: import a catalog, export placed orders.
// Uses the JsonValue model in json.mbt (author's own benchlens code).

///|
// ---------- catalog import ----------

/// Import a catalog from a JSON array:
/// [{"id":"kb-01","name":"Mech Keyboard","category":"peripherals",
///   "price_cents":49900,"stock":10}, ...]
/// Returns the number of products imported; malformed entries are skipped.
pub fn store_import_json(store : Store, content : String) -> Int {
  let mut imported = 0
  match json_parse(content) {
    JArray(items) =>
      for item in items {
        match item {
          JObject(fields) => {
            let mut id = ""
            let mut name = ""
            let mut name_en : String? = None
            let mut category = ""
            let mut price = 0
            let mut stock = 0
            let mut ok = true
            for field in fields {
              match (field.0, field.1) {
                ("id", JString(v)) => id = v
                ("name", JString(v)) => name = v
                ("name_en", JString(v)) => name_en = Some(v)
                ("category", JString(v)) => category = v
                ("price_cents", JNumber(v)) => price = v.to_int()
                ("stock", JNumber(v)) => stock = v.to_int()
                _ => ()
              }
            }
            if id == "" || name == "" || price <= 0 || stock < 0 {
              ok = false
            }
            if ok {
              let product = match name_en {
                Some(en) => product_new(id, name, category, price, name_en=en)
                None => product_new(id, name, category, price)
              }
              store_add_product(store, product, stock)
              imported = imported + 1
            }
          }
          _ => ()
        }
      }
    _ => ()
  }
  imported
}

///|
// ---------- order export ----------

fn order_to_json(order : Order) -> JsonValue {
  let lines : Array[JsonValue] = []
  for l in order.lines {
    let line_fields : Array[(String, JsonValue)] = [
      ("product_id", JString(l.product_id)),
      ("name", JString(l.name)),
      ("unit_price_cents", JNumber(l.unit_price_cents.to_double())),
      ("qty", JNumber(l.qty.to_double())),
    ]
    match l.name_en {
      Some(en) => line_fields.push(("name_en", JString(en)))
      None => ()
    }
    lines.push(JObject(line_fields))
  }
  let b = order.breakdown
  let head : Array[(String, JsonValue)] = [
    ("order_no", JString(order.order_no)),
    ("lines", JArray(lines)),
    ("subtotal", JNumber(b.subtotal.to_double())),
    ("bulk_discount", JNumber(b.bulk_discount.to_double())),
    ("rebate_off", JNumber(b.rebate_off.to_double())),
  ]
  match b.coupon_code {
    Some(code) => head.push(("coupon_code", JString(code)))
    None => ()
  }
  head.push(("coupon_off", JNumber(b.coupon_off.to_double())))
  head.push(("shipping", JNumber(b.shipping.to_double())))
  head.push(("total", JNumber(b.total.to_double())))
  JObject(head)
}

/// Export all placed orders as a compact JSON array.
pub fn orders_export_json(store : Store) -> String {
  let arr : Array[JsonValue] = []
  for order in store.orders {
    arr.push(order_to_json(order))
  }
  json_serialize(JArray(arr))
}

///|
// ---------- catalog export & order import (round-trip) ----------

fn opt_string_json(v : String?) -> JsonValue {
  match v {
    Some(s) => JString(s)
    None => JNull
  }
}

/// Export the current catalog (products with live stock) as a JSON array
/// in the same shape `store_import_json` accepts, so a store can be
/// snapshotted and restored.
pub fn catalog_export_json(store : Store) -> String {
  let arr : Array[JsonValue] = []
  for item in store.items {
    arr.push(
      JObject(
        [
          ("id", JString(item.product.id)),
          ("name", JString(item.product.name)),
          ("name_en", opt_string_json(item.product.name_en)),
          ("category", JString(item.product.category)),
          ("price_cents", JNumber(item.product.price_cents.to_double())),
          ("stock", JNumber(item.stock.to_double())),
        ],
      ),
    )
  }
  json_serialize(JArray(arr))
}

/// Import previously exported orders (the `orders_export_json` format)
/// into the store's order history, and bump the order-number sequence
/// past the highest imported order so new orders never collide.
/// Returns the number of orders imported; malformed entries are skipped.
pub fn orders_import_json(store : Store, content : String) -> Int {
  let mut imported = 0
  let mut max_seq = 0
  match json_parse(content) {
    JArray(items) =>
      for item in items {
        match parse_order_json(item) {
          Some((order, seq)) => {
            store.orders.push(order)
            if seq > max_seq {
              max_seq = seq
            }
            imported = imported + 1
          }
          None => ()
        }
      }
    _ => ()
  }
  if max_seq > order_seq.n {
    order_seq.n = max_seq
  }
  imported
}

fn parse_order_json(item : JsonValue) -> (Order, Int)? {
  match item {
    JObject(fields) => {
      let mut order_no = ""
      let lines : Array[OrderLine] = []
      let mut subtotal = 0
      let mut bulk_discount = 0
      let mut rebate_off = 0
      let mut coupon_code : String? = None
      let mut coupon_off = 0
      let mut shipping = 0
      let mut total = 0
      for field in fields {
        match (field.0, field.1) {
          ("order_no", JString(v)) => order_no = v
          ("lines", JArray(items)) =>
            for li in items {
              match li {
                JObject(lf) => {
                  let mut pid = ""
                  let mut name = ""
                  let mut name_en : String? = None
                  let mut unit = 0
                  let mut qty = 0
                  for f in lf {
                    match (f.0, f.1) {
                      ("product_id", JString(v)) => pid = v
                      ("name", JString(v)) => name = v
                      ("name_en", JString(v)) => name_en = Some(v)
                      ("unit_price_cents", JNumber(v)) => unit = v.to_int()
                      ("qty", JNumber(v)) => qty = v.to_int()
                      _ => ()
                    }
                  }
                  if pid != "" && name != "" && unit > 0 && qty > 0 {
                    lines.push(
                      { product_id: pid, name, name_en, unit_price_cents: unit, qty },
                    )
                  }
                }
                _ => ()
              }
            }
          ("subtotal", JNumber(v)) => subtotal = v.to_int()
          ("bulk_discount", JNumber(v)) => bulk_discount = v.to_int()
          ("rebate_off", JNumber(v)) => rebate_off = v.to_int()
          ("coupon_code", JString(v)) => coupon_code = Some(v)
          ("coupon_off", JNumber(v)) => coupon_off = v.to_int()
          ("shipping", JNumber(v)) => shipping = v.to_int()
          ("total", JNumber(v)) => total = v.to_int()
          _ => ()
        }
      }
      if order_no == "" || lines.length() == 0 {
        return None
      }
      // derive the numeric part of "MO-000123" for sequence bookkeeping
      let mut seq = 0
      for _, ch in order_no {
        if ch >= '0' && ch <= '9' {
          seq = seq * 10 + (ch.to_int() - '0'.to_int())
        }
      }
      let breakdown : PriceBreakdown = {
        subtotal,
        bulk_discount,
        rebate_off,
        coupon_code,
        coupon_off,
        shipping,
        total,
      }
      Some(({ order_no, lines, breakdown }, seq))
    }
    _ => None
  }
}
