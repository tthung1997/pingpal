// @open packs/corgi/sheet.png
// @base art/corgi/base_sheet.png
// @layout art/corgi/layout.json
// Finishing pass for the corgi sheet, run headless by LibreSprite (see tools/art/build.py).
//
// The base sheet (art/corgi/base_sheet.png) is the cut-out, re-pixelated reference art made by
// tools/art/prep_sheet.py, and already contains the Zzz, "?" and tears from the references. This
// script only adds the little mood symbols the references do not have:
//   happy -> hearts      alert -> an exclamation mark
// each placed next to that frame's body box (from art/corgi/layout.json) and outlined to match.

var ROWS = ['idle', 'walk', 'sleep', 'thinking', 'happy', 'alert', 'sad'];   // must match prep_sheet.py ANIMS
var FRAMES = 4;
var CW = LAYOUT.cell[0], CH = LAYOUT.cell[1];
var OUT = '#2a1210';
var C = { red: '#ff5a4d', redL: '#ff9a90', pink: '#ff8fa3', pinkL: '#ffd0d8' };

function pick(arr, f) { return arr[f % arr.length]; }

function heart(b, x, y, c, d) {
  b.rect(x + 1, y, 2, 1, c); b.rect(x + 4, y, 2, 1, c); b.rect(x, y + 1, 7, 2, c); b.rect(x + 1, y + 3, 5, 1, c);
  b.rect(x + 2, y + 4, 3, 1, c); b.px(x + 3, y + 5, c); b.px(x + 1, y + 1, d);
}

// Draws the extras for one frame into a transparent cell-sized buffer.
function extrasFor(name, f, d) {
  var e = new Buf(CW, CH);
  // Just right of the body at head height, but far enough in that two hearts and their outline
  // (up to ~16px wide) never spill into the neighbouring frame.
  var ex = Math.min(d[2] + 2, CW - 19), ey = Math.max(d[1] - 2, 4);
  if (name == 'happy') {
    heart(e, ex, ey + 8 + pick([0, -3, -6, -4], f), C.red, C.redL);
    if (f >= 2) heart(e, ex + 7, ey + 2 + pick([0, 0, 0, -2], f), C.pink, C.pinkL);
  } else if (name == 'alert') {
    e.rect(ex + 3, ey, 3, 11, C.red); e.rect(ex + 3, ey + 13, 3, 3, C.red);
    e.px(ex + 3, ey, C.redL); e.px(ex + 3, ey + 1, C.redL);
  }
  return e;
}

var IMG = SPR.layer(0).cel(0).image;
var W = SPR.width, H = SPR.height;
var sheet = new Buf(W, H);
var raw = IMG.getImageData();
for (var i = 0; i < raw.length; i++) sheet.d[i] = raw[i];

for (var r = 0; r < ROWS.length; r++) {
  var name = ROWS[r];
  if (name != 'happy' && name != 'alert') continue;
  for (var f = 0; f < FRAMES; f++) {
    var layer = outlined(extrasFor(name, f, LAYOUT.frames[name][f].dog), OUT);   // (CW+2) x (CH+2)
    blit(sheet, layer, f * CW - 1, r * CH - 1);
  }
}

IMG.putImageData(sheet.d);
SPR.save();
console.log('corgi sheet done ' + W + 'x' + H);
