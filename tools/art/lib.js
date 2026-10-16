// PingPal art library for LibreSprite scripts (pure ES5: LibreSprite's JS engine is old).
// Not run directly: tools/art/build.py prepends an app.open(...) header and concatenates this
// file with a sheet script. Pixel-buffer helpers only; the scripts hold the art itself.

var _c = {};
function col(h) {
  if (typeof h !== 'string') return h;
  var r = _c[h];
  if (!r) { var n = parseInt(h.slice(1), 16); r = _c[h] = [(n >> 16) & 255, (n >> 8) & 255, n & 255, 255]; }
  return r;
}

function Buf(w, h) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); }
Buf.prototype.px = function (x, y, c) {
  x = Math.floor(x); y = Math.floor(y);
  if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
  var i = (y * this.w + x) * 4, k = col(c);
  this.d[i] = k[0]; this.d[i + 1] = k[1]; this.d[i + 2] = k[2]; this.d[i + 3] = 255;
};
Buf.prototype.a = function (x, y) {
  if (x < 0 || y < 0 || x >= this.w || y >= this.h) return 0;
  return this.d[(y * this.w + x) * 4 + 3];
};
Buf.prototype.rect = function (x, y, w, h, c) {
  for (var j = 0; j < h; j++) for (var i = 0; i < w; i++) this.px(x + i, y + j, c);
};
Buf.prototype.ell = function (cx, cy, rx, ry, c) {
  for (var y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++)
    for (var x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
      var dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry;
      if (dx * dx + dy * dy <= 1) this.px(x, y, c);
    }
};
// Triangle: apex column cx, first row `top`, h rows, half-width hw at the base.
Buf.prototype.tri = function (cx, top, h, hw, c) {
  for (var r = 0; r < h; r++) {
    var w = Math.round(hw * (r + 1) / h);
    for (var x = cx - w; x <= cx + w; x++) this.px(x, top + r, c);
  }
};
Buf.prototype.line = function (x0, y0, x1, y1, c, t) {
  t = t || 1;
  var dx = Math.abs(x1 - x0), dy = Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, e = dx - dy;
  while (true) {
    this.rect(x0, y0, t, t, c);
    if (x0 == x1 && y0 == y1) break;
    var e2 = 2 * e;
    if (e2 > -dy) { e -= dy; x0 += sx; }
    if (e2 < dx) { e += dx; y0 += sy; }
  }
};

// Runs fn(tmp) and copies what it drew onto `base`, but only where base is already opaque.
// Used for shading that must not spill past a shape's edge.
function onto(base, fn) {
  var t = new Buf(base.w, base.h);
  fn(t);
  for (var i = 0; i < t.d.length; i += 4) {
    if (t.d[i + 3] && base.d[i + 3]) {
      base.d[i] = t.d[i]; base.d[i + 1] = t.d[i + 1]; base.d[i + 2] = t.d[i + 2]; base.d[i + 3] = 255;
    }
  }
}

// 1px outline in colour c around every opaque pixel (4-neighbour); result is 2px larger per axis.
function outlined(b, c) {
  var o = new Buf(b.w + 2, b.h + 2), x, y;
  for (y = 0; y < b.h; y++) for (x = 0; x < b.w; x++)
    if (b.a(x, y)) { var i = (y * b.w + x) * 4; o.px(x + 1, y + 1, [b.d[i], b.d[i + 1], b.d[i + 2]]); }
  for (y = 0; y < o.h; y++) for (x = 0; x < o.w; x++) {
    if (o.a(x, y)) continue;
    if (b.a(x - 2, y - 1) || b.a(x, y - 1) || b.a(x - 1, y - 2) || b.a(x - 1, y)) o.px(x, y, c);
  }
  return o;
}

function blit(dst, src, ox, oy) {
  for (var y = 0; y < src.h; y++) for (var x = 0; x < src.w; x++) {
    var s = (y * src.w + x) * 4;
    if (!src.d[s + 3]) continue;
    var X = ox + x, Y = oy + y;
    if (X < 0 || Y < 0 || X >= dst.w || Y >= dst.h) continue;
    var d = (Y * dst.w + X) * 4;
    dst.d[d] = src.d[s]; dst.d[d + 1] = src.d[s + 1]; dst.d[d + 2] = src.d[s + 2]; dst.d[d + 3] = 255;
  }
}

var _SRC_ALPHA = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
function srcCrop(sx, sy, w, h) {
  var b = new Buf(w, h);
  for (var y = 0; y < h; y++) {
    var row = SRC_ROWS[sy + y];
    if (!row) continue;
    for (var x = 0; x < w; x++) {
      var ch = row.charAt(sx + x);
      if (!ch || ch === '.') continue;
      var idx = _SRC_ALPHA.indexOf(ch);
      if (idx >= 0) b.px(x, y, SRC_PAL[idx]);
    }
  }
  return b;
}
