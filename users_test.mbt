// Tests for the account system: SHA-256 vectors, password auth,
// role gating and session lifecycle.

///|
test "sha256 matches FIPS 180-4 test vectors" {
  inspect(
    @moonshop.sha256_hex(""),
    content="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
  inspect(
    @moonshop.sha256_hex("abc"),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  // 56-byte input forces an extra padding block
  inspect(
    @moonshop.sha256_hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    content="248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
  )
}

///|
test "password hashing is salted, stretched and verified" {
  let h1 = @moonshop.password_hash("secret", "salt-a")
  let h2 = @moonshop.password_hash("secret", "salt-b")
  // different salts -> different hashes for the same password
  inspect(h1 != h2, content="true")
  // deterministic for the same salt
  inspect(@moonshop.password_hash("secret", "salt-a") == h1, content="true")
  // stretched output is the chain of 1000 rounds, not a single hash
  inspect(h1 != @moonshop.sha256_hex("salt-a:secret"), content="true")
}

///|
test "register, login, logout lifecycle" {
  let acc = @moonshop.accounts_new()
  inspect(@moonshop.accounts_register(acc, "alice", "hunter22", @moonshop.Customer), content="true")
  // duplicates and weak input rejected
  inspect(@moonshop.accounts_register(acc, "alice", "hunter22", @moonshop.Customer), content="false")
  inspect(@moonshop.accounts_register(acc, "bo", "hunter22", @moonshop.Customer), content="false")
  inspect(@moonshop.accounts_register(acc, "bob", "abc", @moonshop.Customer), content="false")
  // wrong password -> no session
  match @moonshop.accounts_login(acc, "alice", "wrong!!", 0) {
    Some(_) => inspect("logged in", content="REACHED")
    None => inspect("rejected", content="rejected")
  }
  match @moonshop.accounts_login(acc, "alice", "hunter22", 0) {
    Some(session) => {
      inspect(@moonshop.role_label(session.role), content="customer")
      // authenticate resolves the user
      match @moonshop.accounts_authenticate(acc, session.token, 10) {
        Some(user) => inspect(user.username, content="alice")
        None => inspect("no user", content="REACHED")
      }
      // logout invalidates the token
      inspect(@moonshop.accounts_logout(acc, session.token), content="true")
      match @moonshop.accounts_authenticate(acc, session.token, 10) {
        Some(_) => inspect("still valid", content="REACHED")
        None => inspect("gone", content="gone")
      }
    }
    None => inspect("login failed", content="REACHED")
  }
}

///|
test "role hierarchy gates protected actions" {
  let acc = @moonshop.accounts_new()
  @moonshop.accounts_seed_demo(acc)
  let mut admin_token = ""
  let mut customer_token = ""
  match @moonshop.accounts_login(acc, "admin", "admin123", 0) {
    Some(s) => admin_token = s.token
    None => ()
  }
  match @moonshop.accounts_login(acc, "demo", "demo123", 0) {
    Some(s) => customer_token = s.token
    None => ()
  }
  // admin passes the Admin gate; customer does not
  match @moonshop.accounts_require(acc, admin_token, 0, @moonshop.Admin) {
    Some(user) => inspect(user.username, content="admin")
    None => inspect("denied", content="REACHED")
  }
  match @moonshop.accounts_require(acc, customer_token, 0, @moonshop.Admin) {
    Some(_) => inspect("allowed", content="REACHED")
    None => inspect("denied", content="denied")
  }
  // but customer passes the Customer gate
  match @moonshop.accounts_require(acc, customer_token, 0, @moonshop.Customer) {
    Some(user) => inspect(user.username, content="demo")
    None => inspect("denied", content="REACHED")
  }
  // garbage token fails everywhere
  match @moonshop.accounts_require(acc, "forged", 0, @moonshop.Customer) {
    Some(_) => inspect("allowed", content="REACHED")
    None => inspect("denied", content="denied")
  }
  // password change works and old password stops working
  inspect(@moonshop.accounts_change_password(acc, "demo", "demo123", "newpass9"), content="true")
  match @moonshop.accounts_login(acc, "demo", "demo123", 0) {
    Some(_) => inspect("old still works", content="REACHED")
    None => inspect("old rejected", content="old rejected")
  }
  match @moonshop.accounts_login(acc, "demo", "newpass9", 0) {
    Some(_) => inspect("new works", content="new works")
    None => inspect("new failed", content="REACHED")
  }
}

///|
test "sessions expire on the logical clock" {
  let acc = @moonshop.accounts_new()
  ignore(@moonshop.accounts_register(acc, "bob", "hunter22", @moonshop.Staff))
  match @moonshop.accounts_login(acc, "bob", "hunter22", 0) {
    Some(session) => {
      inspect(session.expires_at, content="3600")
      // still valid inside the TTL
      match @moonshop.accounts_require(acc, session.token, 3600, @moonshop.Staff) {
        Some(_) => inspect("valid", content="valid")
        None => inspect("expired", content="REACHED")
      }
      // expired afterwards, and the dead session is swept
      match @moonshop.accounts_require(acc, session.token, 3601, @moonshop.Staff) {
        Some(_) => inspect("valid", content="REACHED")
        None => inspect("expired", content="expired")
      }
      inspect(acc.sessions.length(), content="0")
    }
    None => inspect("login failed", content="REACHED")
  }
}
