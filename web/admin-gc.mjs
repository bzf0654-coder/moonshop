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
    get_value: (el) => el.value,
  },
  spectest: {
    print_char: log,
  },
  array: {
    new: () => [],
    push: (array, value) => { array.push(value); },
    iter: (arr, cb) => arr.forEach(cb),
  },
  storage: {
    // k/v arrive as real JS strings (MoonBit JsString on wasm-gc IS a
    // JS string created via string.fromCodePoint); get returns a
    // code-point array (empty when missing) per the snake pattern.
    get: (k) => {
      try {
        const v = localStorage.getItem(k);
        return v === null ? [] : Array.from(v, (c) => c.codePointAt(0) || 0);
      } catch (e) { return []; }
    },
    set: (k, v) => {
      try { localStorage.setItem(k, v); } catch (e) { /* quota — ignore */ }
    },
    del: (k) => {
      try { localStorage.removeItem(k); } catch (e) {}
    },
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
  fetch("./admin.wasm"),
  importObject,
);
instance.exports._start();
flush();
