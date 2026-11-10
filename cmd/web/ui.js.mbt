// Browser DOM externs — JavaScript backend only.
// Follows the official snake-example FFI pattern (moonbit-docs).

#external

pub type JsString

pub fn JsString::from_string(str : String) -> JsString = "%identity"

pub fn JsString::to_string(str : JsString) -> String = "%identity"

#external
pub type El

extern "js" fn get_el(id : String) -> El =
  #|(id) => document.getElementById(id)

fn El::set_html(self : El, html : String) -> Unit {
  self.set_html_ffi(JsString::from_string(html))
}

extern "js" fn El::set_html_ffi(self : El, html : JsString) -> Unit =
  #|(el, html) => el.innerHTML = html

extern "js" fn El::on_click(self : El, cb : () -> Unit) -> Unit =
  #|(el, cb) => el.onclick = () => cb()

// localStorage persistence (js backend): empty string means missing.
extern "js" fn storage_get(key : String) -> String =
  #|(key) => {
  #|  const v = localStorage.getItem(key);
  #|  return v === null ? "" : v;
  #|}

extern "js" fn storage_set(key : String, value : String) -> Unit =
  #|(key, value) => {
  #|  try { localStorage.setItem(key, value) } catch (e) {}
  #|}

extern "js" fn storage_del(key : String) -> Unit =
  #|(key) => {
  #|  try { localStorage.removeItem(key) } catch (e) {}
  #|}
