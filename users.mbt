// Account system: salted password authentication, roles and sessions.
//
// Crypto is a hand-written SHA-256 (FIPS 180-4) in pure MoonBit — no
// third-party dependency, testable against the standard vectors. Password
// verification is salted + iterated (key stretching) and compared in
// constant time. Salt derivation is deterministic (no CSPRNG in pure
// MoonBit); a host RNG bridge is the documented production upgrade.

///|
// ---------- SHA-256 ----------

let sha256_k : Array[UInt32] = [
  0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU,
  0x59f111f1U, 0x923f82a4U, 0xab1c5ed5U, 0xd807aa98U, 0x12835b01U,
  0x243185beU, 0x550c7dc3U, 0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U,
  0xc19bf174U, 0xe49b69c1U, 0xefbe4786U, 0x0fc19dc6U, 0x240ca1ccU,
  0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU, 0x983e5152U,
  0xa831c66dU, 0xb00327c8U, 0xbf597fc7U, 0xc6e00bf3U, 0xd5a79147U,
  0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU,
  0x53380d13U, 0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U,
  0xa2bfe8a1U, 0xa81a664bU, 0xc24b8b70U, 0xc76c51a3U, 0xd192e819U,
  0xd6990624U, 0xf40e3585U, 0x106aa070U, 0x19a4c116U, 0x1e376c08U,
  0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU, 0x5b9cca4fU,
  0x682e6ff3U, 0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U,
  0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U,
]

fn u32(x : Int) -> UInt32 {
  // Int -> UInt32 via the codepoint route (valid for byte-scale values)
  match x.to_char() {
    Some(c) => c.to_uint()
    None => 0U
  }
}

fn rotr(x : UInt32, n : Int) -> UInt32 {
  (x >> n) | (x << (32 - n))
}

fn hex_char(v : Int) -> Char {
  let digits = "0123456789abcdef"
  match digits.get_char(v) {
    Some(c) => c
    None => '0'
  }
}

fn word_hex(w : UInt32) -> String {
  let buf = StringBuilder()
  for i in 0..<8 {
    let nibble = ((w >> (28 - i * 4)) & 0x0FU).reinterpret_as_int()
    buf.write_char(hex_char(nibble))
  }
  buf.to_string()
}

// UTF-8 encode one codepoint into the byte stream.
fn utf8_push(bytes : Array[UInt32], code : Int) -> Unit {
  if code < 0x80 {
    bytes.push(u32(code))
  } else if code < 0x800 {
    bytes.push(u32(0xC0 | (code >> 6)))
    bytes.push(u32(0x80 | (code & 0x3F)))
  } else if code < 0x10000 {
    bytes.push(u32(0xE0 | (code >> 12)))
    bytes.push(u32(0x80 | ((code >> 6) & 0x3F)))
    bytes.push(u32(0x80 | (code & 0x3F)))
  } else {
    bytes.push(u32(0xF0 | (code >> 18)))
    bytes.push(u32(0x80 | ((code >> 12) & 0x3F)))
    bytes.push(u32(0x80 | ((code >> 6) & 0x3F)))
    bytes.push(u32(0x80 | (code & 0x3F)))
  }
}

/// SHA-256 of a string, hex-encoded (lowercase). Runs the compression
/// `rounds` times (key stretching); `sha256_hex` is rounds = 1.
pub fn sha256_hex_rounds(input : String, rounds : Int) -> String {
  let bytes : Array[UInt32] = []
  for _, ch in input {
    utf8_push(bytes, ch.to_int())
  }
  let bit_len = bytes.length() * 8
  bytes.push(u32(0x80))
  while bytes.length() % 64 != 56 {
    bytes.push(u32(0))
  }
  // 64-bit big-endian bit length (high word zero for demo-scale inputs)
  bytes.push(u32(0))
  bytes.push(u32(0))
  bytes.push(u32(0))
  bytes.push(u32(0))
  bytes.push(u32((bit_len >> 24) & 0xFF))
  bytes.push(u32((bit_len >> 16) & 0xFF))
  bytes.push(u32((bit_len >> 8) & 0xFF))
  bytes.push(u32(bit_len & 0xFF))
  let mut h0 = 0x6a09e667U
  let mut h1 = 0xbb67ae85U
  let mut h2 = 0x3c6ef372U
  let mut h3 = 0xa54ff53aU
  let mut h4 = 0x510e527fU
  let mut h5 = 0x9b05688cU
  let mut h6 = 0x1f83d9abU
  let mut h7 = 0x5be0cd19U
  let w : Array[UInt32] = Array::make(64, 0U)
  let blocks = bytes.length() / 64
  for _ in 0..<(if rounds < 1 { 1 } else { rounds }) {
    for block in 0..<blocks {
      let base = block * 64
      for i in 0..<16 {
        let j = base + i * 4
        w[i] = (bytes[j] << 24) | (bytes[j + 1] << 16) | (bytes[j + 2] << 8) | bytes[j + 3]
      }
      for i in 16..<64 {
        let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
        let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
        w[i] = w[i - 16] + s0 + w[i - 7] + s1
      }
      let mut a = h0
      let mut b = h1
      let mut c = h2
      let mut d = h3
      let mut e = h4
      let mut f = h5
      let mut g = h6
      let mut hh = h7
      for i in 0..<64 {
        let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
        let ch = (e & f) ^ ((e ^ 0xffffffffU) & g)
        let t1 = hh + s1 + ch + sha256_k[i] + w[i]
        let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
        let maj = (a & b) ^ (a & c) ^ (b & c)
        let t2 = s0 + maj
        hh = g
        g = f
        f = e
        e = d + t1
        d = c
        c = b
        b = a
        a = t1 + t2
      }
      h0 = h0 + a
      h1 = h1 + b
      h2 = h2 + c
      h3 = h3 + d
      h4 = h4 + e
      h5 = h5 + f
      h6 = h6 + g
      h7 = h7 + hh
    }
  }
  word_hex(h0) + word_hex(h1) + word_hex(h2) + word_hex(h3) +
  word_hex(h4) + word_hex(h5) + word_hex(h6) + word_hex(h7)
}

/// Single-round SHA-256, hex-encoded.
pub fn sha256_hex(input : String) -> String {
  sha256_hex_rounds(input, 1)
}

///|
// ---------- password hashing ----------

/// Key-stretching rounds for stored password hashes.
pub const PASSWORD_ROUNDS : Int = 1000

/// Salted + stretched hash: sha256(salt + ":" + password) x PASSWORD_ROUNDS.
pub fn password_hash(password : String, salt : String) -> String {
  sha256_hex_rounds(salt + ":" + password, PASSWORD_ROUNDS)
}

/// Constant-time equality for hex digests (no early exit on mismatch).
fn ct_eq(a : String, b : String) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut diff = 0
  for i in 0..<a.length() {
    diff = diff | ((a[i].to_int() ^ b[i].to_int()) & 0xFF)
  }
  diff == 0
}

///|
// ---------- roles & permissions ----------

#derive(Debug)
pub(all) enum Role {
  Customer
  Staff
  Admin
}

pub extend Role with @debug.Debug::{to_repr}

/// Whether `r` carries at least the authority of `min`
/// (Admin > Staff > Customer).
pub fn role_at_least(r : Role, min : Role) -> Bool {
  match (r, min) {
    (Admin, _) => true
    (Staff, Customer) | (Staff, Staff) => true
    (Customer, Customer) => true
    (_, _) => false
  }
}

/// Machine label ("admin" / "staff" / "customer") for APIs and storage.
pub fn role_label(r : Role) -> String {
  match r {
    Admin => "admin"
    Staff => "staff"
    Customer => "customer"
  }
}

/// Parse a role label; None for unknown strings.
pub fn role_parse(s : String) -> Role? {
  match s {
    "admin" => Some(Admin)
    "staff" => Some(Staff)
    "customer" => Some(Customer)
    _ => None
  }
}

///|
// ---------- accounts & sessions ----------

/// A registered account. `hash` is the salted+stretched digest; the
/// plaintext password never leaves this struct's constructor.
#derive(Debug)
pub struct User {
  username : String
  salt : String
  hash : String
  role : Role
}

pub extend User with @debug.Debug::{to_repr}

/// An authenticated session; expiry uses the same logical clock as stock
/// reservations (host bridges may pass real epoch seconds).
#derive(Debug)
pub struct Session {
  token : String
  username : String
  role : Role
  expires_at : Int
}

pub extend Session with @debug.Debug::{to_repr}

/// The account store: users, live sessions and the salt/token counter.
#derive(Debug)
pub struct Accounts {
  users : Array[User]
  sessions : Array[Session]
  mut seq : Int
}

pub extend Accounts with @debug.Debug::{to_repr}

/// Create an empty account store.
pub fn accounts_new() -> Accounts {
  { users: [], sessions: [], seq: 0 }
}

fn accounts_find_user(acc : Accounts, username : String) -> User? {
  for user in acc.users {
    if user.username == username {
      return Some(user)
    }
  }
  None
}

/// Register a new account. Rules: username >= 3 chars and unique,
/// password >= 6 chars, role must be known. Returns false otherwise.
pub fn accounts_register(
  acc : Accounts,
  username : String,
  password : String,
  role : Role
) -> Bool {
  if username.length() < 3 || password.length() < 6 {
    return false
  }
  match accounts_find_user(acc, username) {
    Some(_) => return false
    None => ()
  }
  acc.seq = acc.seq + 1
  let salt = sha256_hex("moonshop-salt:" + acc.seq.to_string())
  let hash = password_hash(password, salt)
  acc.users.push({ username, salt, hash, role })
  true
}

/// Seed the demo accounts (admin/admin123 as Admin, demo/demo123 as
/// Customer). Existing usernames are left untouched.
pub fn accounts_seed_demo(acc : Accounts) -> Unit {
  ignore(accounts_register(acc, "admin", "admin123", Admin))
  ignore(accounts_register(acc, "demo", "demo123", Customer))
}

/// Verify credentials and open a session valid until logical tick
/// `now + SESSION_TTL_TICKS`. None on bad credentials.
pub fn accounts_login(
  acc : Accounts,
  username : String,
  password : String,
  now : Int
) -> Session? {
  match accounts_find_user(acc, username) {
    Some(user) => {
      let candidate = password_hash(password, user.salt)
      if ct_eq(candidate, user.hash) {
        acc.seq = acc.seq + 1
        let token = sha256_hex(
          "moonshop-token:" + username + ":" + acc.seq.to_string() + ":" + now.to_string(),
        )
        let session : Session = {
          token,
          username,
          role: user.role,
          expires_at: now + SESSION_TTL_TICKS,
        }
        acc.sessions.push(session)
        return Some(session)
      }
      None
    }
    None => None
  }
}

/// Close a session. Returns false when the token is unknown.
pub fn accounts_logout(acc : Accounts, token : String) -> Bool {
  for i, s in acc.sessions {
    if s.token == token {
      ignore(acc.sessions.remove(i))
      return true
    }
  }
  false
}

/// Resolve a live session to its user. Expired sessions are swept.
pub fn accounts_authenticate(acc : Accounts, token : String, now : Int) -> User? {
  for i, s in acc.sessions {
    if s.token == token {
      if s.expires_at < now {
        ignore(acc.sessions.remove(i))
        return None
      }
      return accounts_find_user(acc, s.username)
    }
  }
  None
}

/// Authenticate AND require at least `min` authority. None when the
/// token is invalid or the role is insufficient.
pub fn accounts_require(
  acc : Accounts,
  token : String,
  now : Int,
  min : Role
) -> User? {
  match accounts_authenticate(acc, token, now) {
    Some(user) =>
      if role_at_least(user.role, min) {
        Some(user)
      } else {
        None
      }
    None => None
  }
}

/// Change a password after verifying the old one.
pub fn accounts_change_password(
  acc : Accounts,
  username : String,
  old_password : String,
  new_password : String
) -> Bool {
  if new_password.length() < 6 {
    return false
  }
  for i, user in acc.users {
    if user.username == username {
      let candidate = password_hash(old_password, user.salt)
      if ct_eq(candidate, user.hash) {
        acc.seq = acc.seq + 1
        let salt = sha256_hex("moonshop-salt:" + acc.seq.to_string())
        acc.users[i] = {
          username: user.username,
          salt,
          hash: password_hash(new_password, salt),
          role: user.role,
        }
        return true
      }
      return false
    }
  }
  false
}

/// Session lifetime in logical ticks (demo default: one "hour").
pub const SESSION_TTL_TICKS : Int = 3600

///|
// ---------- persistence ----------

/// Export users (salted hashes only — never plaintext) and live
/// sessions as JSON for host-side persistence.
pub fn accounts_export_json(acc : Accounts) -> String {
  let users : Array[JsonValue] = []
  for u in acc.users {
    users.push(
      JObject(
        [
          ("username", JString(u.username)),
          ("salt", JString(u.salt)),
          ("hash", JString(u.hash)),
          ("role", JString(role_label(u.role))),
        ],
      ),
    )
  }
  let sessions : Array[JsonValue] = []
  for s in acc.sessions {
    sessions.push(
      JObject(
        [
          ("token", JString(s.token)),
          ("username", JString(s.username)),
          ("role", JString(role_label(s.role))),
          ("expires_at", JNumber(s.expires_at.to_double())),
        ],
      ),
    )
  }
  json_serialize(
    JObject([("users", JArray(users)), ("sessions", JArray(sessions))]),
  )
}

/// Import previously exported accounts. Returns the number of users
/// imported; malformed entries and duplicates are skipped.
pub fn accounts_import_json(acc : Accounts, content : String) -> Int {
  let mut imported = 0
  match json_parse(content) {
    JObject(fields) =>
      for field in fields {
        match (field.0, field.1) {
          ("users", JArray(items)) =>
            for item in items {
              match item {
                JObject(uf) => {
                  let mut username = ""
                  let mut salt = ""
                  let mut hash = ""
                  let mut role : Role? = None
                  for f in uf {
                    match (f.0, f.1) {
                      ("username", JString(v)) => username = v
                      ("salt", JString(v)) => salt = v
                      ("hash", JString(v)) => hash = v
                      ("role", JString(v)) => role = role_parse(v)
                      _ => ()
                    }
                  }
                  let ok = username != "" && salt != "" && hash != ""
                  match (ok, role) {
                    (true, Some(r)) =>
                      match accounts_find_user(acc, username) {
                        Some(_) => ()
                        None => {
                          acc.users.push({ username, salt, hash, role: r })
                          imported = imported + 1
                        }
                      }
                    _ => ()
                  }
                }
                _ => ()
              }
            }
          _ => ()
        }
      }
    _ => ()
  }
  acc.seq = acc.seq + imported
  imported
}
