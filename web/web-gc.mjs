// moonshop wasm-gc loader — instantiates the MoonBit wasm-gc module and
// provides the host imports (DOM bridge, string/closure helpers).
// Pattern follows the official MoonBit snake example.

// console output from MoonBit println (char-coded, UTF-16)
const [log, flush] = (() => {
  var buffer = [];
  function flush() {
    if (buffer.length > 0) {
      console.log(new TextDecoder("utf-16").decode(new Uint16Array(buffer).valueOf()));
      buffer = [];
    }
  }
  function log(ch) {
    if (ch === "\n".charCodeAt(0)) { flush(); }
    else if (ch === "\r".charCodeAt(0)) { /* noop */ }
    else { buffer.push(ch); }
  }
  return [log, flush];
})();

const importObject = {
  dom: {
    get_el: (id) => document.getElementById(id),
    set_html: (el, html) => { el.innerHTML = html; },
    on_click: (el, cb) => { el.onclick = () => cb(); },
  },
  spectest: {
    print_char: log,
  },
  array: {
    new: () => [],
    push: (array, value) => { array.push(value); },
  },
  string: {
    fromCodePoint: (points) => String.fromCodePoint(...points),
    iter: (str, callback) => {
      for (const ch of str) { callback(ch.codePointAt(0) || 0); }
    },
  },
  Math: {
    random: Math.random,
    floor: Math.floor,
  },
  "moonbit:ffi": {
    make_closure: (funcref, closure) => funcref.bind(null, closure),
  },
};

const { instance } = await WebAssembly.instantiateStreaming(
  fetch("./web.wasm"),
  importObject,
);
instance.exports._start();
flush();
