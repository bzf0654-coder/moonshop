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
