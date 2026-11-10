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
            let mut category = ""
            let mut price = 0
            let mut stock = 0
            let mut ok = true
            for field in fields {
              match (field.0, field.1) {
                ("id", JString(v)) => id = v
                ("name", JString(v)) => name = v
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
              store_add_product(store, product_new(id, name, category, price), stock)
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
    lines.push(
      JObject(
        [
          ("product_id", JString(l.product_id)),
          ("name", JString(l.name)),
          ("unit_price_cents", JNumber(l.unit_price_cents.to_double())),
          ("qty", JNumber(l.qty.to_double())),
        ],
      ),
    )
  }
  let b = order.breakdown
  JObject(
    [
      ("order_no", JString(order.order_no)),
      ("lines", JArray(lines)),
      ("subtotal", JNumber(b.subtotal.to_double())),
      ("bulk_discount", JNumber(b.bulk_discount.to_double())),
      ("coupon_off", JNumber(b.coupon_off.to_double())),
      ("shipping", JNumber(b.shipping.to_double())),
      ("total", JNumber(b.total.to_double())),
    ],
  )
}

/// Export all placed orders as a compact JSON array.
pub fn orders_export_json(store : Store) -> String {
  let arr : Array[JsonValue] = []
  for order in store.orders {
    arr.push(order_to_json(order))
  }
  json_serialize(JArray(arr))
}
