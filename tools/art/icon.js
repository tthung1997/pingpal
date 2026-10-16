// @open icon.png
// @source art/corgi/base_sheet.png
// @canvas 104x104
// Game icon: pixel-art corgi head wearing headphones and glasses, built headless by LibreSprite.

var CW = 89, CH = 131;
var GW = 52, GH = 52; // 1x pixel-art grid (scaled 2x nearest-neighbour into the 104x104 icon)
var OX = -16, OY = -34; // shifts head bbox (x=18..65, y=36..82) to (x=2..49, y=2..48) in the 52x52 grid

var P = {
  out: '#1d0a09',
  line: '#42261f',
  lineMid: '#50342a',
  furDeep: '#91502a',
  furBright: '#f2a558',
  creamMidD: '#ccab84',
  creamMid: '#daae80',
  creamSoft: '#e5be8f',
  creamLight: '#edd3ad',
  creamBright: '#fbe2ba',
  creamWhite: '#fdeed3',
  hpDark: '#1e2430',
  hpMid: '#2d3748',
  hpCyanD: '#0284c7',
  hpCyan: '#38bdf8',
  hpCyanHi: '#bae6fd',
  glassFrame: '#1d0a09',
  glassRim: '#332324',
  glassGold: '#e39952',
  glassGlint: '#e0f2fe'
};

function isDark(buf, x, y) {
  if (!buf.a(x, y)) return false;
  var i = (y * buf.w + x) * 4;
  return (buf.d[i] + buf.d[i + 1] + buf.d[i + 2]) < 140;
}

function drawHead(b) {
  var src = srcCrop(89, 0, CW, CH);
  var raw = new Buf(CW, CH);

  // Copy head from source frame 1 (x=19..65, y=36..80), rounding the lower cheeks and chin cleanly
  for (var y = 36; y <= 80; y++) {
    var minX = 19, maxX = 65;
    if (y === 74) { minX = 24; maxX = 60; }
    else if (y === 75) { minX = 26; maxX = 59; }
    else if (y === 76) { minX = 28; maxX = 58; }
    else if (y === 77) { minX = 31; maxX = 56; }
    else if (y === 78) { minX = 34; maxX = 54; }
    else if (y === 79) { minX = 37; maxX = 51; }
    else if (y === 80) { minX = 41; maxX = 47; }

    for (var x = minX; x <= maxX; x++) {
      var si = (y * CW + x) * 4;
      if (!src.d[si + 3]) continue;
      var di = (y * CW + x) * 4;
      raw.d[di] = src.d[si];
      raw.d[di + 1] = src.d[si + 1];
      raw.d[di + 2] = src.d[si + 2];
      raw.d[di + 3] = 255;
    }
  }

  // Fill the 2px gap between left ear inner base and crown under the headband
  raw.rect(38, 49, 4, 2, P.furBright);

  // Clean up right-side smile crease next to the nose
  raw.rect(51, 70, 5, 6, P.creamLight);
  raw.rect(50, 71, 4, 4, P.creamBright);

  // Repaint the mouth into a clean, focused corgi muzzle
  var my = 75;
  raw.rect(38, my, 17, 3, P.creamBright);
  raw.rect(40, my, 13, 2, P.creamWhite);
  raw.rect(37, my + 2, 17, 2, P.creamLight);
  raw.rect(38, my + 3, 15, 2, P.creamSoft);
  raw.rect(41, my + 5, 7, 1, P.creamMid);
  // Restore nose bottom tip
  raw.rect(46, my - 1, 4, 1, P.out);
  raw.rect(47, my, 2, 1, P.out);
  raw.px(47, my + 1, P.line);
  // Focused closed mouth line
  raw.rect(43, my + 2, 8, 1, P.out);
  raw.px(42, my + 2, P.line);
  raw.px(51, my + 2, P.line);
  raw.px(41, my + 3, P.lineMid);
  raw.px(52, my + 3, P.lineMid);
  raw.rect(44, my + 3, 6, 1, P.creamMid);
  raw.rect(45, my + 4, 4, 1, P.creamMidD);

  // Ensure a continuous 1px dark outline along the newly rounded bottom cheek/chin contour (y >= 73)
  var head = new Buf(CW, CH);
  blit(head, raw, 0, 0);
  var dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
  for (var cy = 73; cy <= 81; cy++) {
    for (var cx = 22; cx <= 62; cx++) {
      if (raw.a(cx, cy)) continue;
      var needsOut = false;
      for (var d = 0; d < 4; d++) {
        var nx = cx + dirs[d][0], ny = cy + dirs[d][1];
        if (raw.a(nx, ny)) {
          needsOut = true;
          break;
        }
      }
      if (needsOut) head.px(cx, cy, P.out);
    }
  }

  blit(b, head, OX, OY);
}

function drawHeadphones(b) {
  var hp = new Buf(CW, CH);
  // Continuous headband arch passing IN FRONT of both ears from left cup to right cup
  for (var x = 20; x <= 62; x++) {
    var t = (x - 41) / 20.0;
    var drop = (t < 0) ? Math.round(13 * t * t) : Math.round(10 * t * t);
    var y = 45 + drop;
    hp.px(x, y, (Math.abs(x - 41) <= 10) ? P.hpCyanHi : P.hpCyan);
    hp.px(x, y + 1, P.hpCyan);
    hp.px(x, y + 2, P.hpMid);
    if (Math.abs(x - 41) > 13) {
      hp.px(x, y + 3, P.hpDark);
    }
  }

  // Left ear cup (x=19..24, y=58..67)
  var ly = 58;
  hp.rect(20, ly, 4, 10, P.hpMid);
  hp.rect(19, ly + 1, 6, 8, P.hpMid);
  hp.rect(23, ly + 1, 2, 8, P.hpDark);
  hp.rect(19, ly + 2, 3, 6, P.hpCyanD);
  hp.rect(19, ly + 3, 2, 4, P.hpCyan);
  hp.px(19, ly + 3, P.hpCyanHi);

  // Right ear cup (x=59..64, y=55..64)
  var ry = 55;
  hp.rect(60, ry, 4, 10, P.hpMid);
  hp.rect(59, ry + 1, 6, 8, P.hpMid);
  hp.rect(59, ry + 1, 2, 8, P.hpDark);
  hp.rect(61, ry + 2, 3, 6, P.hpCyanD);
  hp.rect(62, ry + 3, 2, 4, P.hpCyan);
  hp.px(62, ry + 3, P.hpCyanHi);

  var ohp = outlined(hp, P.out);
  blit(b, ohp, OX - 1, OY - 1);
}

function drawGlassesAndBrows(b) {
  var g = new Buf(CW, CH);
  var ly = 62, ry = 60;

  // Left lens rim (x=33..43, y=ly..ly+7)
  g.rect(34, ly, 9, 1, P.glassFrame);
  g.rect(34, ly + 7, 9, 1, P.glassFrame);
  g.rect(33, ly + 1, 1, 6, P.glassFrame);
  g.rect(43, ly + 1, 1, 6, P.glassFrame);
  g.px(35, ly, P.glassGold);
  g.px(36, ly, P.glassRim);

  // Right lens rim (x=47..56, y=ry..ry+7)
  g.rect(48, ry, 8, 1, P.glassFrame);
  g.rect(48, ry + 7, 8, 1, P.glassFrame);
  g.rect(47, ry + 1, 1, 6, P.glassFrame);
  g.rect(56, ry + 1, 1, 6, P.glassFrame);
  g.px(49, ry, P.glassGold);
  g.px(50, ry, P.glassRim);

  // Bridge between lenses
  g.rect(44, ly + 2, 3, 1, P.glassGold);
  g.rect(44, ly + 3, 3, 1, P.glassFrame);

  // Temple arms to headphone cups
  g.line(25, ly + 2, 32, ly + 2, P.glassFrame);
  g.line(57, ry + 2, 59, ry + 2, P.glassFrame);

  // Lens glint
  g.px(35, ly + 2, P.creamWhite);
  g.px(36, ly + 1, P.glassGlint);
  g.px(49, ry + 2, P.creamWhite);
  g.px(50, ry + 1, P.glassGlint);

  // Serious furrowed eyebrows above frame
  g.line(35, ly - 3, 42, ly - 1, P.out);
  g.line(35, ly - 4, 41, ly - 2, P.furDeep);
  g.line(54, ry - 3, 48, ry - 1, P.out);
  g.line(54, ry - 4, 49, ry - 2, P.furDeep);

  blit(b, g, OX, OY);
}

var grid = new Buf(GW, GH);
drawHead(grid);
drawHeadphones(grid);
drawGlassesAndBrows(grid);

var IMG = SPR.layer(0).cel(0).image;
var W = SPR.width, H = SPR.height;
var out = new Buf(W, H);
var scale = Math.floor(W / GW);

for (var y = 0; y < GH; y++) {
  for (var x = 0; x < GW; x++) {
    var si = (y * GW + x) * 4;
    if (!grid.d[si + 3]) continue;
    out.rect(x * scale, y * scale, scale, scale, [grid.d[si], grid.d[si + 1], grid.d[si + 2]]);
  }
}

IMG.putImageData(out.d);
SPR.save();
console.log('icon done ' + W + 'x' + H);
