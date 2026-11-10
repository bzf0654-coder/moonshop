// Browser DOM imports for the wasm-gc backend.
// Same surface as ui.js.mbt; the host side lives in web/web-gc.mjs.
// String bridging follows the official snake-example pattern (moonbit-docs).

#external
priv type JsArray

fn JsArray::new() -> JsArray = "array" "new"

fn JsArray::push(self : JsArray, charCode : Int) -> Unit = "array" "push"

#external
pub(all) type JsString

fn JsString::from_code_point(charCode : JsArray) -> JsString = "string" "fromCodePoint"

fn JsString::iter(self : JsString, f : (Int) -> Unit) -> Unit = "string" "iter"

pub fn JsString::from_string(str : String) -> JsString {
  str
  .iter()
  .fold(
    fn(array : JsArray, char : Char) {
      array.push(char.to_int())
      array
    },
    init=JsArray::new(),
  )
  |> JsString::from_code_point
}

pub fn JsString::to_string(str : JsString) -> String {
  let buffer = StringBuilder()
  str.iter(fn(i : Int) { buffer.write_char(i.unsafe_to_char()) })
  buffer.to_string()
}

#external
pub type El

fn get_el_ffi(id : JsString) -> El = "dom" "get_el"

fn get_el(id : String) -> El {
  get_el_ffi(JsString::from_string(id))
}

fn El::set_html_ffi(self : El, html : JsString) -> Unit = "dom" "set_html"

fn El::set_html(self : El, html : String) -> Unit {
  self.set_html_ffi(JsString::from_string(html))
}

fn El::on_click(self : El, cb : () -> Unit) -> Unit = "dom" "on_click"

// localStorage persistence (wasm-gc backend): strings cross the boundary
// as code-point arrays (snake-example pattern); empty array = missing.
fn JsArray::iter(self : JsArray, f : (Int) -> Unit) -> Unit = "array" "iter"

fn storage_get(key : String) -> String {
  let points = storage_get_ffi(JsString::from_string(key))
  let buf = StringBuilder()
  points.iter(fn(i) { buf.write_char(i.unsafe_to_char()) })
  buf.to_string()
}

fn storage_get_ffi(key : JsString) -> JsArray = "storage" "get"

fn storage_set(key : String, value : String) -> Unit {
  storage_set_ffi(JsString::from_string(key), JsString::from_string(value))
}

fn storage_set_ffi(key : JsString, value : JsString) -> Unit = "storage" "set"

fn storage_del(key : String) -> Unit {
  storage_del_ffi(JsString::from_string(key))
}

fn storage_del_ffi(key : JsString) -> Unit = "storage" "del"
