// Pricing engine: line items -> bulk discount -> coupon -> shipping.
// All stages in Int cents; coupon savings are capped so totals stay >= 0.

///|
// ---------- pricing rules ----------

/// Orders reaching this subtotal (after bulk discount, before coupon) ship free.
pub const FREE_SHIPPING_THRESHOLD_CENTS : Int = 9900

/// Flat shipping fee below the free-shipping threshold.
pub const SHIPPING_FEE_CENTS : Int = 800

/// Bulk pricing: buying at least this many units of one product earns BULK_DISCOUNT_PCT off that line.
pub const BULK_MIN_QTY : Int = 3

/// Bulk discount percentage (per line, floor-rounded).
pub const BULK_DISCOUNT_PCT : Int = 5

///|
// ---------- tiered shipping ----------

/// Orders at or above this amount (post-coupon) ship free.
pub const SHIPPING_FREE_CENTS : Int = 9900

/// Standard shipping fee for the middle band.
pub const SHIPPING_STANDARD_CENTS : Int = 800

/// Orders below this amount pay a small-order surcharge instead.
pub const SHIPPING_SMALL_MAX_CENTS : Int = 4900

/// Surcharge for small orders (heavy handling relative to basket value).
pub const SHIPPING_SURCHARGE_CENTS : Int = 1200

/// Tiered shipping by post-coupon amount, evaluated top-down:
/// >= 99 CNY -> free; >= 49 CNY -> standard 8 CNY; else surcharge 12 CNY.
pub fn shipping_fee_for(amount : Int) -> Int {
  if amount >= SHIPPING_FREE_CENTS {
    0
  } else if amount >= SHIPPING_SMALL_MAX_CENTS {
    SHIPPING_STANDARD_CENTS
  } else {
    SHIPPING_SURCHARGE_CENTS
  }
}

///|
// ---------- coupon ----------

/// A fixed-amount coupon usable when the (post-bulk, post-rebate) subtotal
/// reaches `min_spend_cents`.
#derive(Debug)
pub struct Coupon {
  code : String
  off_cents : Int
  min_spend_cents : Int
}

pub extend Coupon with @debug.Debug::{to_repr}

/// Construct a coupon: code, amount off (cents), minimum spend (cents).
pub fn coupon_new(code : String, off_cents : Int, min_spend_cents : Int) -> Coupon {
  { code, off_cents, min_spend_cents }
}

///|
// ---------- rebate (满减) ----------

/// An order-level threshold rebate: orders whose post-bulk subtotal
/// reaches `min_spend_cents` earn a flat `off_cents` off (capped at the
/// basket value). Applied before coupons.
#derive(Debug)
pub struct Rebate {
  min_spend_cents : Int
  off_cents : Int
}

pub extend Rebate with @debug.Debug::{to_repr}

/// Construct a rebate: minimum spend (cents), amount off (cents).
pub fn rebate_new(min_spend_cents : Int, off_cents : Int) -> Rebate {
  { min_spend_cents, off_cents }
}

///|
// ---------- price breakdown ----------

/// The full pricing pipeline result. Stages run in a fixed order:
/// line totals -> member discount -> bulk discount -> rebate (满减)
/// -> coupon -> tiered shipping.
/// `total = subtotal - member_off - bulk_discount - rebate_off
/// - coupon_off + shipping`, always >= 0.
#derive(Debug)
pub struct PriceBreakdown {
  subtotal : Int
  member_off : Int
  bulk_discount : Int
  rebate_off : Int
  coupon_code : String?
  coupon_off : Int
  shipping : Int
  total : Int
}

pub extend PriceBreakdown with @debug.Debug::{to_repr}

/// Price a cart against the store. Returns None when the cart references
/// a product the store does not carry.
pub fn price_cart(
  store : Store,
  cart : Cart,
  coupon : Coupon?,
  rebate? : Rebate,
  member_off_pct? : Int
) -> PriceBreakdown? {
  let mut subtotal = 0
  let mut bulk_discount = 0
  for line in cart.lines {
    match store_find(store, line.product_id) {
      Some(product) => {
        let line_total = product.price_cents * line.qty
        subtotal = subtotal + line_total
        if line.qty >= BULK_MIN_QTY {
          bulk_discount = bulk_discount + line_total * BULK_DISCOUNT_PCT / 100
        }
      }
      None => return None
    }
  }
  // member stage: percent off the goods subtotal, clamped to 0..=50
  let pct = match member_off_pct {
    Some(p) => if p < 0 { 0 } else if p > 50 { 50 } else { p }
    None => 0
  }
  let member_off = subtotal * pct / 100
  let after_bulk = subtotal - member_off - bulk_discount
  // rebate stage: threshold on the post-bulk subtotal, capped
  let mut rebate_off = 0
  match rebate {
    Some(r) =>
      if after_bulk >= r.min_spend_cents {
        rebate_off = r.off_cents
        if rebate_off > after_bulk {
          rebate_off = after_bulk
        }
      }
    None => ()
  }
  let after_rebate = after_bulk - rebate_off
  // coupon stage: threshold on the post-rebate subtotal, capped
  let mut coupon_code : String? = None
  let mut coupon_off = 0
  match coupon {
    Some(c) =>
      if after_rebate >= c.min_spend_cents {
        coupon_code = Some(c.code)
        coupon_off = c.off_cents
        if coupon_off > after_rebate {
          coupon_off = after_rebate
        }
      }
    None => ()
  }
  let after_coupon = after_rebate - coupon_off
  let shipping = shipping_fee_for(after_coupon)
  Some(
    {
      subtotal,
      member_off,
      bulk_discount,
      rebate_off,
      coupon_code,
      coupon_off,
      shipping,
      total: after_coupon + shipping,
    },
  )
}
