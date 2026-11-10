// Receipt rendering: Markdown receipts for placed orders.

///|
// ---------- money formatting ----------

/// Format cents as "¥499.00" / "¥-0.50".
pub fn format_cents(cents : Int) -> String {
  let neg = cents < 0
  let abs = if neg { -cents } else { cents }
  let yuan = abs / 100
  let fen = abs % 100
  let mut fen_str = fen.to_string()
  while fen_str.length() < 2 {
    fen_str = "0" + fen_str
  }
  "¥" + (if neg { "-" } else { "" }) + yuan.to_string() + "." + fen_str
}

///|
// ---------- receipt ----------

/// Render an order as a GitHub-flavoured Markdown receipt.
pub fn order_receipt(order : Order) -> String {
  let buf = StringBuilder()
  buf.write_string("## Receipt " + order.order_no + "\n\n")
  buf.write_string("| item | qty | unit | line total |\n")
  buf.write_string("|---|---:|---:|---:|\n")
  for line in order.lines {
    let line_total = line.unit_price_cents * line.qty
    buf.write_string(
      "| " + line.name + " | " + line.qty.to_string() + " | " +
      format_cents(line.unit_price_cents) + " | " +
      format_cents(line_total) + " |\n",
    )
  }
  let b = order.breakdown
  buf.write_string("\n")
  buf.write_string("- subtotal: " + format_cents(b.subtotal) + "\n")
  if b.bulk_discount > 0 {
    buf.write_string(
      "- bulk discount (qty ≥ " + BULK_MIN_QTY.to_string() + "): -" +
      format_cents(b.bulk_discount) + "\n",
    )
  }
  match b.coupon_code {
    Some(code) =>
      buf.write_string(
        "- coupon " + code + ": -" + format_cents(b.coupon_off) + "\n",
      )
    None => ()
  }
  buf.write_string(
    "- shipping: " +
    (if b.shipping == 0 { "free" } else { format_cents(b.shipping) }) +
    "\n",
  )
  buf.write_string("- **total: " + format_cents(b.total) + "**\n")
  buf.to_string()
}
