// Browser DOM imports for the wasm-gc backend.
// Same surface as ui.js.mbt; the host side lives in web/web-gc.mjs.
// String bridging follows the official snake-example pattern (moonbit-docs).

#external
priv type JsArray

fn JsArray::new() -> JsArray = "array" "new"

fn JsArray::push(self : JsArray, charCode : Int) -> Unit = "array" "push"

#external
pub(all) type JsText

fn JsText::from_code_point(charCode : JsArray) -> JsText = "string" "fromCodePoint"

fn JsText::iter(self : JsText, f : (Int) -> Unit) -> Unit = "string" "iter"

pub fn JsText::from_string(str : String) -> JsText {
  str
  .iter()
  .fold(
    fn(array : JsArray, char : Char) {
      array.push(char.to_int())
      array
    },
    init=JsArray::new(),
  )
  |> JsText::from_code_point
}

pub fn JsText::to_string(str : JsText) -> String {
  let buffer = StringBuilder()
  str.iter(fn(i : Int) { buffer.write_char(i.unsafe_to_char()) })
  buffer.to_string()
}

#external
pub type El

fn get_el_ffi(id : JsText) -> El = "dom" "get_el"

pub fn get_el(id : String) -> El {
  get_el_ffi(JsText::from_string(id))
}

fn El::set_html_ffi(self : El, html : JsText) -> Unit = "dom" "set_html"

pub fn El::set_html(self : El, html : String) -> Unit {
  self.set_html_ffi(JsText::from_string(html))
}

pub fn El::on_click(self : El, cb : () -> Unit) -> Unit = "dom" "on_click"

// localStorage persistence (wasm-gc backend): strings cross the boundary
// as code-point arrays (snake-example pattern); empty array = missing.
fn JsArray::iter(self : JsArray, f : (Int) -> Unit) -> Unit = "array" "iter"

pub fn storage_get(key : String) -> String {
  let points = storage_get_ffi(JsText::from_string(key))
  let buf = StringBuilder()
  points.iter(fn(i) { buf.write_char(i.unsafe_to_char()) })
  buf.to_string()
}

fn storage_get_ffi(key : JsText) -> JsArray = "storage" "get"

pub fn storage_set(key : String, value : String) -> Unit {
  storage_set_ffi(JsText::from_string(key), JsText::from_string(value))
}

fn storage_set_ffi(key : JsText, value : JsText) -> Unit = "storage" "set"

pub fn storage_del(key : String) -> Unit {
  storage_del_ffi(JsText::from_string(key))
}

fn storage_del_ffi(key : JsText) -> Unit = "storage" "del"

// Input element value bridge (admin forms). The host returns a real JS
// string, which is exactly what JsText wraps — convert via codepoints.
pub fn El::get_value_ffi(self : El) -> JsText = "dom" "get_value"

pub fn El::get_value(self : El) -> String {
  self.get_value_ffi().to_string()
}
