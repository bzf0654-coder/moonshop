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
