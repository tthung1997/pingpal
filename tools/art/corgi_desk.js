// @open packs/corgi_desk/sheet.png
// @source art/corgi/base_sheet.png
// @canvas 356x524
// @proof-canvas 89x131
// Corgi at a deskcharacter pack, built headless by LibreSprite (tools/art/build.py).

var CW = 89, CH = 131;
var OUT = '#1d0a09';

var P = {
  out: '#1d0a09',
  outSoft: '#291919',
  line: '#42261f',
  lineMid: '#50342a',
  // Fur palette (matches art/corgi/base_sheet.png)
  furDeep: '#91502a',
  furDark: '#a4663c',
  furMidD: '#c97838',
  furMid: '#e39952',
  furBright: '#f2a558',
  furLight: '#f6b366',
  creamDeep: '#bc8353',
  creamDark: '#c29c75',
  creamMidD: '#ccab84',
  creamMid: '#daae80',
  creamSoft: '#e5be8f',
  creamLight: '#edd3ad',
  creamBright: '#fbe2ba',
  creamHi: '#fde8c3',
  creamWhite: '#fdeed3',
  // Chair (warm dark charcoal + amber bolster trim)
  chairDeep: '#1f1b24',
  chairDark: '#2a2533',
  chairMid: '#373142',
  chairLight: '#474056',
  chairHi: '#5a526b',
  chairTrim: '#c97838',
  chairTrimHi: '#f0b069',
  // Hoodie (cozy slate-indigo)
  hoodDeep: '#1b2838',
  hoodDark: '#25364a',
  hoodMid: '#324860',
  hoodLight: '#425d7a',
  hoodHi: '#567696',
  // Headphones & glasses
  hpDark: '#1e2430',
  hpMid: '#2d3748',
  hpLight: '#4a5568',
  hpCyanD: '#0284c7',
  hpCyan: '#38bdf8',
  hpCyanHi: '#bae6fd',
  glassFrame: '#1d0a09',
  glassRim: '#332324',
  glassGold: '#e39952',
  glassTint: '#a5d8ff',
  glassGlint: '#e0f2fe',
  // Desk (warm walnut/oak wood)
  woodDeep: '#3b2114',
  woodDark: '#522f1d',
  woodEdge: '#6b3e26',
  woodShadow: '#824d30',
  woodMid: '#9c603e',
  woodLight: '#b5744e',
  woodHi: '#cc8860',
  woodBevel: '#deb08a',
  // Keyboard & laptop & mug
  kbDark: '#1e222a',
  kbMid: '#2e3440',
  kbLight: '#434c5e',
  keyLight: '#e5e9f0',
  keyShadow: '#aeb6c4',
  keyAccent: '#ebcb8b',
  keyCyan: '#38bdf8',
  mugDark: '#b84a39',
  mugMid: '#d9624e',
  mugHi: '#f28b79',
  coffee: '#42261f',
  // Bone & Sleep mask & Attention extras
  boneShadow: '#c29c75',
  boneMid: '#edd3ad',
  boneLight: '#fbe2ba',
  boneHi: '#fdeed3',
  maskDeep: '#4a3556',
  maskDark: '#634873',
  maskMid: '#7e5e91',
  maskLight: '#9b7ab0',
  maskHi: '#bca0cf',
  maskTrim: '#fbe2ba',
  pinkDark: '#c95b6b',
  pinkLight: '#ff9ebb',
  alertRed: '#ff5a4d',
  alertHi: '#ff9a90'
};

function drawChair(b) {
  // Inner fill of ergonomic chair (will be outlined)
  var c = new Buf(CW, CH);
  // Headrest behind neck/ears (rounded top)
  c.rect(30, 45, 26, 2, P.chairLight);
  c.rect(28, 47, 30, 10, P.chairMid);
  c.rect(31, 48, 24, 8, P.chairDark);
  // Main backrest with angled gaming-chair bolsters
  for (var y = 57; y <= 102; y++) {
    var spread = y < 75 ? Math.round((y - 57) * 0.42) : Math.round((75 - 57) * 0.42 - (y - 75) * 0.14);
    var lx = 22 - spread, rx = 63 + spread;
    c.rect(lx, y, rx - lx + 1, 1, P.chairMid);
    // Highlight on outer bolster edges
    c.px(lx, y, P.chairLight);
    c.px(lx + 1, y, P.chairLight);
    c.px(rx, y, P.chairDark);
    c.px(rx - 1, y, P.chairDeep);
    // Inner recessed back panel
    if (y >= 60 && y <= 98) {
      c.rect(lx + 5, y, rx - lx - 9, 1, P.chairDark);
      // Warm amber stitching lines along bolsters
      c.px(lx + 4, y, (y % 2 === 0) ? P.chairTrim : P.chairDeep);
      c.px(rx - 4, y, (y % 2 === 0) ? P.chairTrim : P.chairDeep);
    }
  }
  // Chair armrests tucked neatly beside the hoodie elbows
  c.rect(15, 92, 5, 2, P.chairLight);
  c.rect(16, 92, 3, 1, P.chairHi);
  c.rect(15, 94, 5, 8, P.chairDeep);

  c.rect(65, 92, 5, 2, P.chairLight);
  c.rect(66, 92, 3, 1, P.chairHi);
  c.rect(65, 94, 5, 8, P.chairDeep);

  var oc = outlined(c, P.out);
  blit(b, oc, -1, -1);
}

function drawCorgiHeadAndRuff(b, dy, mode, f) {
  // Extract the upright head and upper neck ruff from idle frame 1 (sx=89, sy=0)
  var src = srcCrop(89, 0, CW, CH);
  var head = new Buf(CW, CH);
  for (var y = 36; y <= 86; y++) {
    for (var x = 19; x <= 65; x++) {
      // Taper the lower neck ruff into a cozy V-shape (y=77..86) so it tucks into the hoodie V-neck
      if (y >= 77) {
        var t = y - 77; // 0..9
        var minX = 24 + Math.floor(t * 1.4);
        var maxX = 59 - Math.floor(t * 1.2);
        if (x < minX || x > maxX) continue;
      }
      var si = (y * CW + x) * 4;
      if (!src.d[si + 3]) continue;
      var ty = y + dy;
      var di = (ty * CW + x) * 4;
      head.d[di] = src.d[si];
      head.d[di + 1] = src.d[si + 1];
      head.d[di + 2] = src.d[si + 2];
      head.d[di + 3] = 255;
    }
  }

  // Clean up the old right-side smile crease next to the nose (y=70..75, x=51..55 in source)
  var ny = 70 + dy;
  head.rect(51, ny, 5, 6, P.creamLight);
  head.rect(50, ny + 1, 4, 4, P.creamBright);

  // Subtle eye-shine / gaze variation by mode
  if (mode === 'idle' && f === 2) {
    // Glance 1px left across the code on frame 2
    head.px(38, 65 + dy, P.creamWhite);
    head.px(39, 65 + dy, P.out);
    head.px(50, 63 + dy, P.creamWhite);
    head.px(51, 63 + dy, P.out);
  } else if (mode === 'bone' && (f % 2 === 0)) {
    // Extra happy eye-sparkle on chomp frames
    head.px(39, 65 + dy, P.creamWhite);
    head.px(51, 63 + dy, P.creamWhite);
  } else if (mode === 'attention') {
    // Extra bright attentive eye sparkle
    head.px(39, 65 + dy, P.creamWhite);
    head.px(38, 66 + dy, P.creamWhite);
    head.px(51, 63 + dy, P.creamWhite);
    head.px(50, 64 + dy, P.creamWhite);
  }

  // Repaint the mouth (y=75..83 in source) according to mode
  var my = 75 + dy;
  head.rect(38, my, 17, 3, P.creamBright);
  head.rect(40, my, 13, 2, P.creamWhite);
  head.rect(37, my + 2, 18, 4, P.creamLight);
  head.rect(38, my + 4, 16, 3, P.creamSoft);
  head.rect(40, my + 6, 11, 2, P.creamMid);
  // Restore nose bottom tip so it stays crisp
  head.rect(46, my - 1, 4, 1, P.out);
  head.rect(47, my, 2, 1, P.out);
  head.px(47, my + 1, P.line);

  if (mode === 'idle') {
    // Serious, focused closed mouth line
    head.rect(43, my + 2, 8, 1, P.out);
    head.px(42, my + 2, P.line);
    head.px(51, my + 2, P.line);
    head.px(41, my + 3, P.lineMid);
    head.px(52, my + 3, P.lineMid);
    head.rect(44, my + 3, 6, 1, P.creamMid);
    head.rect(45, my + 4, 4, 1, P.creamMidD);
  } else if (mode === 'sleep') {
    // Peaceful sleeping mouth (tiny relaxed 'o' / soft breathing line)
    head.rect(45, my + 2, 4, 1, P.line);
    if (f >= 2) {
      head.rect(46, my + 2, 2, 2, P.out);
      head.px(46, my + 3, P.pinkDark);
    }
    head.rect(44, my + 3, 6, 1, P.creamMid);
  } else if (mode === 'bone') {
    // Chewing mouth (open slightly on odd frames)
    head.rect(42, my + 2, 10, 2, P.out);
    if (f % 2 === 1) {
      head.rect(44, my + 3, 6, 2, P.pinkDark);
      head.rect(45, my + 3, 4, 1, P.pinkLight);
    }
  } else if (mode === 'attention') {
    // Perked, polite attentive smile ('w' muzzle with tiny cheerful open center)
    head.rect(43, my + 2, 8, 1, P.out);
    head.px(42, my + 1, P.line);
    head.px(51, my + 1, P.line);
    head.rect(45, my + 3, 4, 2, P.out);
    head.rect(46, my + 3, 2, 1, P.pinkLight);
    head.rect(44, my + 5, 6, 1, P.creamMid);
  }

  blit(b, head, 0, 0);
}

function drawHoodie(b, dy, mode, f, leftPawDy, rightPawDy) {
  var h = new Buf(CW, CH);
  var topY = 79 + dy; // ~83

  // Solid torso & shoulders block in cozy slate-indigo hoodie
  for (var y = topY; y <= 104; y++) {
    var t = y - topY;
    var lx = 20 - Math.min(3, Math.floor(t * 0.22));
    var rx = 62 + Math.min(3, Math.floor(t * 0.22));
    for (var x = lx; x <= rx; x++) {
      var c = P.hoodMid;
      if (x < lx + 4 || x > rx - 4) c = P.hoodDark;
      else if (x < 34 && y < topY + 8) c = P.hoodHi;
      else if (x < 40) c = P.hoodLight;
      else if (x > 52) c = P.hoodDark;
      if (y > 100) c = P.hoodDeep;
      h.px(x, y, c);
    }
  }

  // If raising left hand for attention, angle the left sleeve outward so the raised paw clears the headphone cup!
  if (mode === 'attention') {
    var waveDy = (f === 1 || f === 2) ? -1 : 0;
    var waveDx = (f === 1) ? -1 : ((f === 3) ? 1 : 0);
    for (var ay = 73 + waveDy; ay <= topY + 14; ay++) {
      var shift = Math.round((topY + 14 - ay) * 0.45);
      var sx = 19 - shift + (ay < 80 ? waveDx : 0);
      h.rect(sx, ay, 10, 1, P.hoodMid);
      h.rect(sx + 1, ay, 3, 1, P.hoodHi);
      h.rect(sx + 7, ay, 2, 1, P.hoodDark);
    }
    // Raised wrist cuff just to the left of the headphone cup
    var cx = 10 + waveDx, cy = 71 + waveDy;
    h.rect(cx, cy, 10, 3, P.hoodDeep);
    h.rect(cx + 1, cy + 1, 8, 1, P.hoodDark);
  }

  // Hood collar folds hugging left and right shoulders
  h.rect(22, topY - 1, 10, 4, P.hoodLight);
  h.rect(23, topY - 1, 7, 2, P.hoodHi);
  h.rect(52, topY - 1, 9, 4, P.hoodMid);
  h.rect(53, topY - 1, 6, 2, P.hoodLight);

  // V-neck collar lapels sloping down to x=45, y=topY+11
  h.line(32, topY + 2, 44, topY + 11, P.hoodDeep);
  h.line(31, topY + 2, 43, topY + 11, P.hoodHi);
  h.line(56, topY + 2, 46, topY + 11, P.hoodDeep);
  h.line(57, topY + 2, 47, topY + 11, P.hoodLight);

  // Center zipper/seam below the V-neck
  h.rect(44, topY + 11, 1, 11, P.hoodDeep);
  h.rect(45, topY + 11, 1, 11, P.hoodDark);

  // Kangaroo pocket seam across lower chest
  h.line(33, topY + 15, 55, topY + 15, P.hoodDeep);
  h.line(33, topY + 16, 31, 102, P.hoodDeep);
  h.line(55, topY + 16, 57, 102, P.hoodDeep);

  // Sleeve creases (separating arms from torso)
  if (mode === 'bone') {
    // Arms angled inward toward chest to hold the bone
    h.line(25, topY + 6, 33, 95, P.hoodDeep);
    h.line(26, topY + 6, 34, 95, P.hoodLight);
    h.line(59, topY + 6, 53, 95, P.hoodDeep);
    h.line(58, topY + 6, 52, 95, P.hoodLight);
  } else {
    if (mode !== 'attention') {
      h.line(28, topY + 9, 26, 102, P.hoodDeep);
      h.line(29, topY + 10, 27, 102, P.hoodLight);
      h.rect(25, 99 + leftPawDy, 11, 3, P.hoodDeep);
      h.rect(26, 99 + leftPawDy, 9, 1, P.hoodDark);
    }
    h.line(56, topY + 9, 58, 102, P.hoodDeep);
    h.line(55, topY + 10, 57, 102, P.hoodLight);
    h.rect(47, 99 + rightPawDy, 11, 3, P.hoodDeep);
    h.rect(48, 99 + rightPawDy, 9, 1, P.hoodDark);
  }

  // Hoodie drawstrings with cream tips hanging down front of hoodie
  h.rect(37, topY + 7, 1, 8, P.creamLight);
  h.px(37, topY + 15, P.creamWhite);
  h.rect(51, topY + 7, 1, 7, P.creamLight);
  h.px(51, topY + 14, P.creamWhite);

  var oh = outlined(h, P.out);
  blit(b, oh, -1, -1);
}

function drawHeadphones(b, dy) {
  var hp = new Buf(CW, CH);
  // Continuous headband arch passing IN FRONT of both ears all the way from left cup (x=21) to right cup (x=61)
  for (var x = 20; x <= 62; x++) {
    var t = (x - 41) / 20.0;
    var drop = (t < 0) ? Math.round(13 * t * t) : Math.round(10 * t * t);
    var y = 45 + dy + drop;
    hp.px(x, y, (Math.abs(x - 41) <= 10) ? P.hpCyanHi : P.hpCyan);
    hp.px(x, y + 1, P.hpCyan);
    hp.px(x, y + 2, P.hpMid);
    if (Math.abs(x - 41) > 13) {
      // Side slider thickness where band meets the ear cups in front of the ears
      hp.px(x, y + 3, P.hpDark);
    }
  }

  // Left ear cup (rounded oval hugging left side of head, x=19..24, y=58+dy..68+dy)
  var ly = 58 + dy;
  hp.rect(20, ly, 4, 10, P.hpMid);
  hp.rect(19, ly + 1, 6, 8, P.hpMid);
  hp.rect(23, ly + 1, 2, 8, P.hpDark);      // plush cushion against cheek
  hp.rect(19, ly + 2, 3, 6, P.hpCyanD);     // accent face
  hp.rect(19, ly + 3, 2, 4, P.hpCyan);      // cyan glow strip
  hp.px(19, ly + 3, P.hpCyanHi);            // specular highlight

  // Right ear cup (rounded oval hugging right side of head, x=59..64, y=55+dy..65+dy)
  var ry = 55 + dy;
  hp.rect(60, ry, 4, 10, P.hpMid);
  hp.rect(59, ry + 1, 6, 8, P.hpMid);
  hp.rect(59, ry + 1, 2, 8, P.hpDark);      // plush cushion
  hp.rect(61, ry + 2, 3, 6, P.hpCyanD);     // accent face
  hp.rect(62, ry + 3, 2, 4, P.hpCyan);      // cyan glow strip
  hp.px(62, ry + 3, P.hpCyanHi);            // specular highlight

  var ohp = outlined(hp, P.out);
  blit(b, ohp, -1, -1);
}

function drawGlassesOrSleepMask(b, dy, mode, f) {
  var ly = 62 + dy, ry = 60 + dy;

  if (mode === 'sleep') {
    // Plush contoured sleep mask over the eyes with cream satin piping and dark closed-eye arcs
    var m = new Buf(CW, CH);
    b.rect(25, ly + 2, 7, 2, P.out);
    b.rect(57, ry + 2, 3, 2, P.out);

    // Left pad of sleep mask (x=32..44, y=ly-1..ly+7)
    m.rect(33, ly - 1, 11, 8, P.maskTrim);
    m.rect(32, ly, 13, 6, P.maskMid);
    m.rect(33, ly, 11, 2, P.maskHi);
    m.rect(33, ly + 2, 11, 3, P.maskLight);
    m.rect(33, ly + 5, 11, 1, P.maskDark);

    // Center bridge of mask (x=44..47, y=ly..ly+5)
    m.rect(44, ly - 1, 4, 6, P.maskTrim);
    m.rect(44, ly, 4, 4, P.maskMid);
    m.rect(44, ly, 4, 1, P.maskLight);

    // Right pad of sleep mask (x=47..57, y=ry-1..ry+7)
    m.rect(47, ry - 1, 9, 8, P.maskTrim);
    m.rect(46, ry, 11, 6, P.maskMid);
    m.rect(47, ry, 9, 2, P.maskHi);
    m.rect(47, ry + 2, 9, 3, P.maskLight);
    m.rect(47, ry + 5, 9, 1, P.maskDark);

    // Cute dark sleeping closed-eye arcs stitched onto the mask pads
    m.rect(36, ly + 3, 5, 1, P.out);
    m.px(35, ly + 2, P.out);
    m.px(41, ly + 2, P.out);

    m.rect(49, ry + 3, 5, 1, P.out);
    m.px(48, ry + 2, P.out);
    m.px(54, ry + 2, P.out);

    var om = outlined(m, P.out);
    blit(b, om, -1, -1);
    return;
  }

  // Sleek rectangular pixel glasses positioned cleanly over the eyes
  // Left lens rim (x=33..43, y=ly..ly+7, rounded corners)
  b.rect(34, ly, 9, 1, P.glassFrame);
  b.rect(34, ly + 7, 9, 1, P.glassFrame);
  b.rect(33, ly + 1, 1, 6, P.glassFrame);
  b.rect(43, ly + 1, 1, 6, P.glassFrame);
  b.px(35, ly, P.glassGold);
  b.px(36, ly, P.glassRim);

  // Right lens rim (x=47..56, y=ry..ry+7, rounded corners)
  b.rect(48, ry, 8, 1, P.glassFrame);
  b.rect(48, ry + 7, 8, 1, P.glassFrame);
  b.rect(47, ry + 1, 1, 6, P.glassFrame);
  b.rect(56, ry + 1, 1, 6, P.glassFrame);
  b.px(49, ry, P.glassGold);
  b.px(50, ry, P.glassRim);

  // Bridge between lenses (x=44..46)
  b.rect(44, ly + 2, 3, 1, P.glassGold);
  b.rect(44, ly + 3, 3, 1, P.glassFrame);

  // Temple arms to headphone cups
  b.line(25, ly + 2, 32, ly + 2, P.glassFrame);
  b.line(57, ry + 2, 59, ry + 2, P.glassFrame);

  // Subtle white lens glint in top-left corner of each lens
  b.px(35, ly + 2, P.creamWhite);
  b.px(36, ly + 1, P.glassGlint);
  b.px(49, ry + 2, P.creamWhite);
  b.px(50, ry + 1, P.glassGlint);

  if (mode === 'idle') {
    // Serious furrowed eyebrows 2px ABOVE the top frame
    b.line(35, ly - 3, 42, ly - 1, P.out);
    b.line(35, ly - 4, 41, ly - 2, P.furDeep);
    b.line(54, ry - 3, 48, ry - 1, P.out);
    b.line(54, ry - 4, 49, ry - 2, P.furDeep);
  } else if (mode === 'bone') {
    // Happy relaxed eyebrows
    b.rect(36, ly - 3, 5, 1, P.furDeep);
    b.px(35, ly - 2, P.furDeep);
    b.rect(49, ry - 3, 5, 1, P.furDeep);
    b.px(54, ry - 2, P.furDeep);
  } else if (mode === 'attention') {
    // Perked high eyebrows
    b.rect(36, ly - 4, 5, 1, P.out);
    b.px(35, ly - 3, P.out);
    b.rect(49, ry - 4, 5, 1, P.out);
    b.px(54, ry - 3, P.out);
  }
}

function drawDeskAndComputer(b, mode, f, leftPawDx, leftPawDy, rightPawDx, rightPawDy) {
  // 1. Wooden desk surface (x=4..84, y=103..129)
  var d = new Buf(CW, CH);
  for (var y = 103; y <= 116; y++) {
    var inset = Math.max(0, Math.floor((116 - y) * 0.35));
    var lx = 4 + inset, rx = 84 - inset;
    var col = y < 106 ? P.woodMid : (y < 113 ? P.woodLight : P.woodHi);
    d.rect(lx, y, rx - lx + 1, 1, col);
  }
  d.rect(10, 108, 14, 1, P.woodMid);
  d.rect(62, 111, 16, 1, P.woodMid);
  d.rect(18, 114, 28, 1, P.woodMid);

  // Front edge bevel (y=117..121)
  d.rect(4, 117, 81, 1, P.woodBevel);
  d.rect(4, 118, 81, 3, P.woodEdge);
  d.rect(4, 121, 81, 1, P.woodDark);

  // Desk apron & legs (y=122..128)
  d.rect(7, 122, 75, 3, P.woodDeep);
  d.rect(7, 125, 7, 4, P.woodDark);
  d.rect(8, 125, 2, 4, P.woodEdge);
  d.rect(75, 125, 7, 4, P.woodDark);
  d.rect(76, 125, 2, 4, P.woodEdge);

  var od = outlined(d, P.out);
  blit(b, od, -1, -1);

  // 2. Mechanical Keyboard in the center of the desk (x=22..59, y=104..115)
  b.rect(22, 115, 39, 1, P.woodEdge);
  b.rect(22, 104, 38, 11, P.out);
  b.rect(23, 105, 36, 9, P.kbMid);
  b.rect(23, 112, 36, 2, P.kbDark);
  b.rect(24, 105, 34, 1, P.kbLight);

  // Sculpted keycap rows
  b.rect(25, 106, 3, 2, P.mugMid); // red Esc key
  for (var kx = 29; kx <= 54; kx += 3) {
    b.rect(kx, 106, 2, 2, P.keyLight);
    b.rect(kx, 107, 2, 1, P.keyShadow);
  }
  for (var kx2 = 25; kx2 <= 52; kx2 += 3) {
    b.rect(kx2, 109, 2, 2, P.keyLight);
    b.rect(kx2, 110, 2, 1, P.keyShadow);
  }
  b.rect(54, 109, 3, 2, P.keyCyan); // cyan Enter key
  b.rect(25, 111, 4, 2, P.keyShadow);
  b.rect(30, 111, 3, 2, P.keyShadow);
  b.rect(34, 111, 13, 2, P.keyAccent); // warm yellow/amber spacebar
  b.rect(48, 111, 4, 2, P.keyShadow);
  b.rect(53, 111, 4, 2, P.keyShadow);

  // 3. Paws & Mode-Specific Props
  if (mode === 'idle') {
    drawPaw(b, 26 + leftPawDx, 101 + leftPawDy, leftPawDy > 0);
    drawPaw(b, 47 + rightPawDx, 101 + rightPawDy, rightPawDy > 0);
  } else if (mode === 'sleep') {
    // Both paws resting still on the keyboard edge
    drawPaw(b, 26, 102, false);
    drawPaw(b, 47, 102, false);
  } else if (mode === 'bone') {
    // Paws raised to hold a bone right at the mouth!
    var bdy = (f % 2 === 1) ? 1 : 0;
    drawBoneAndPaws(b, bdy, f);
  } else if (mode === 'attention') {
    // Right paw stays on keyboard; left paw is raised high waving!
    drawPaw(b, 47, 102, false);
    drawRaisedPaw(b, f);
  }

  // 4. Angled Laptop / Monitor on the right side of the desk (seen from the back)
  var mon = new Buf(CW, CH);
  mon.rect(61, 108, 19, 4, P.kbDark);
  mon.rect(62, 109, 17, 2, P.kbMid);
  for (var my = 85; my <= 108; my++) {
    var tilt = Math.floor((my - 85) * 0.13);
    var sx = 63 + tilt;
    mon.px(sx, my, P.kbLight);
    if (my === 85) {
      mon.rect(sx, my, 16, 1, P.kbLight);
    } else {
      mon.rect(sx + 1, my, 15, 1, P.kbMid);
      mon.px(sx + 1, my, P.kbLight);
      mon.px(sx + 14, my, P.kbDark);
      mon.px(sx + 15, my, P.kbDark);
    }
  }
  mon.rect(69, 107, 7, 2, P.kbDark);
  mon.rect(72, 95, 2, 2, P.hpCyanHi);
  mon.px(72, 94, P.hpCyan);
  mon.px(73, 97, P.hpCyan);

  var omon = outlined(mon, P.out);
  blit(b, omon, -1, -1);
  b.rect(61, 113, 20, 1, P.woodEdge);

  // 5. Cute Coffee Mug on the left corner of the desk (x=8..18, y=97..109)
  var mug = new Buf(CW, CH);
  mug.rect(8, 100, 2, 6, P.mugDark);
  mug.px(9, 102, P.woodMid);
  mug.px(9, 103, P.woodMid);
  mug.rect(10, 98, 8, 10, P.mugMid);
  mug.rect(11, 99, 2, 8, P.mugHi);
  mug.rect(16, 99, 2, 8, P.mugDark);
  mug.rect(10, 97, 8, 2, P.creamBright);
  mug.rect(11, 98, 6, 1, P.coffee);
  var omug = outlined(mug, P.out);
  blit(b, omug, -1, -1);
  b.rect(10, 109, 9, 1, P.woodEdge);
  // Subtle drifting steam wisps above mug (shifted clear of the raised sleeve in attention mode)
  var sShift = f % 2;
  var sx = (mode === 'attention') ? 9 : 13;
  b.px(sx + sShift, 93, P.creamLight);
  b.px(sx + 1 - sShift, 91, P.creamBright);
  b.px(sx + sShift, 89, P.creamLight);
}

function drawPaw(b, x, y, pressed) {
  var p = new Buf(14, 10);
  p.rect(3, 0, 7, 2, P.furMid);
  p.rect(4, 0, 5, 2, P.furBright);
  p.rect(2, 2, 9, 4, P.creamBright);
  p.rect(3, 2, 7, 3, P.creamHi);
  p.rect(2, 5, 9, 2, P.creamSoft);
  p.rect(3, 6, 7, 1, P.creamMid);
  p.px(4, 5, P.lineMid); p.px(4, 6, P.out);
  p.px(8, 5, P.lineMid); p.px(8, 6, P.out);
  var op = outlined(p, P.out);
  blit(b, op, x - 1, y - 1);

  if (pressed) {
    b.px(x - 1, y + 4, P.hpCyanHi);
    b.px(x + 12, y + 4, P.hpCyanHi);
  }
}

function drawBoneAndPaws(b, dy, f) {
  // 1. Draw the dog bone in its own outlined buffer so it has a crisp outline separating it from muzzle & paws
  var bn = new Buf(CW, CH);
  var by = 81 + dy;
  var tilt = (f % 2 === 0) ? 0 : 1;
  // Center bone shaft
  bn.rect(37, by + 1, 18, 4, P.boneLight);
  bn.rect(37, by + 1, 18, 1, P.boneHi);
  bn.rect(37, by + 4, 18, 1, P.boneShadow);
  // Left double knobs
  bn.rect(33, by - 1 + tilt, 5, 3, P.boneLight);
  bn.rect(34, by - 1 + tilt, 3, 2, P.boneHi);
  bn.rect(33, by + 3 + tilt, 5, 3, P.boneMid);
  bn.rect(34, by + 5 + tilt, 3, 1, P.boneShadow);
  // Right double knobs
  bn.rect(54, by - 1 - tilt, 5, 3, P.boneLight);
  bn.rect(55, by - 1 - tilt, 3, 2, P.boneHi);
  bn.rect(54, by + 3 - tilt, 5, 3, P.boneMid);
  bn.rect(55, by + 5 - tilt, 3, 1, P.boneShadow);

  var obn = outlined(bn, P.out);
  blit(b, obn, -1, -1);

  // 2. Draw the two front paws in their own outlined buffer gripping the bone from below
  var pw = new Buf(CW, CH);
  // Left paw gripping left side of bone
  pw.rect(29, by + 7, 8, 4, P.hoodDeep); // cuff
  pw.rect(30, by + 6, 7, 2, P.furMid);
  pw.rect(31, by + 3, 7, 4, P.creamBright);
  pw.rect(32, by + 3, 5, 3, P.creamHi);
  pw.px(33, by + 4, P.line);
  pw.px(35, by + 4, P.line);

  // Right paw gripping right side of bone
  pw.rect(53, by + 7, 8, 4, P.hoodDeep); // cuff
  pw.rect(53, by + 6, 7, 2, P.furMid);
  pw.rect(52, by + 3, 7, 4, P.creamBright);
  pw.rect(53, by + 3, 5, 3, P.creamHi);
  pw.px(54, by + 4, P.line);
  pw.px(56, by + 4, P.line);

  var opw = outlined(pw, P.out);
  blit(b, opw, -1, -1);
}

function drawRaisedPaw(b, f) {
  // Left paw raised clearly to the left of the headphone cup (x=10..19, y=60..70)
  var waveDx = (f === 1) ? -1 : ((f === 3) ? 1 : 0);
  var waveDy = (f === 1 || f === 2) ? -1 : 0;
  var px = 11 + waveDx, py = 61 + waveDy;

  var p = new Buf(CW, CH);
  // Ginger wrist connecting into raised hoodie cuff
  p.rect(px + 1, py + 7, 6, 3, P.furMid);
  p.rect(px + 2, py + 7, 4, 2, P.furBright);
  // Rounded cream paw raised up facing the viewer
  p.rect(px + 1, py, 6, 2, P.creamHi);
  p.rect(px, py + 1, 8, 6, P.creamBright);
  p.rect(px + 1, py + 1, 6, 4, P.creamHi);
  p.rect(px + 1, py + 5, 6, 2, P.creamSoft);
  // Cute pink central paw pad & toe separations
  p.rect(px + 3, py + 3, 2, 2, P.pinkLight);
  p.px(px + 3, py + 4, P.pinkDark);
  p.px(px + 2, py + 1, P.line);
  p.px(px + 5, py + 1, P.line);

  // Crisp '!' attention symbol above the raised hand
  var ay = 43 + waveDy;
  p.rect(13, ay, 3, 9, P.alertRed);
  p.rect(13, ay + 11, 3, 3, P.alertRed);
  p.px(13, ay, P.alertHi);
  p.px(13, ay + 1, P.alertHi);
  p.px(13, ay + 11, P.alertHi);

  var op = outlined(p, P.out);
  blit(b, op, -1, -1);
}

function drawZzz(b, f) {
  var z = new Buf(CW, CH);
  function glyphZ(gx, gy, big) {
    if (big) {
      z.rect(gx, gy, 6, 1, P.hpCyanHi);
      z.rect(gx, gy + 1, 6, 1, P.hpCyan);
      z.px(gx + 4, gy + 2, P.hpCyanHi);
      z.px(gx + 3, gy + 3, P.hpCyan);
      z.px(gx + 2, gy + 4, P.hpCyanHi);
      z.px(gx + 1, gy + 5, P.hpCyan);
      z.rect(gx, gy + 6, 6, 1, P.hpCyanHi);
    } else {
      z.rect(gx, gy, 4, 1, P.creamWhite);
      z.px(gx + 2, gy + 1, P.creamBright);
      z.px(gx + 1, gy + 2, P.creamBright);
      z.rect(gx, gy + 3, 4, 1, P.creamWhite);
    }
  }
  if (f === 0) {
    glyphZ(64, 42, false);
  } else if (f === 1) {
    glyphZ(63, 44, false);
    glyphZ(68, 34, true);
  } else if (f === 2) {
    glyphZ(65, 41, false);
    glyphZ(70, 31, true);
  } else {
    glyphZ(66, 39, false);
    glyphZ(71, 28, true);
  }
  var oz = outlined(z, P.out);
  blit(b, oz, -1, -1);
}

function drawFrame(b, mode, f) {
  var dy = 0, leftDx = 0, leftDy = 0, rightDx = 0, rightDy = 0;
  if (mode === 'idle') {
    dy = (f >= 2) ? 1 : 0;
    leftDy = (f % 2 === 0) ? 1 : -1;
    rightDy = (f % 2 === 0) ? -1 : 1;
    leftDx = (f === 2) ? 2 : ((f === 1) ? 1 : 0);
    rightDx = (f === 1) ? -1 : ((f === 3) ? 1 : 0);
  } else if (mode === 'bone') {
    dy = (f % 2 === 1) ? 1 : 0;
  } else if (mode === 'sleep') {
    dy = (f >= 2) ? 2 : 1;
    leftDy = 1;
    rightDy = 1;
  } else if (mode === 'attention') {
    dy = (f === 1 || f === 2) ? -1 : 0;
    rightDy = 1;
  }

  drawChair(b);
  drawHoodie(b, 4 + dy, mode, f, leftDy, rightDy);
  drawCorgiHeadAndRuff(b, 4 + dy, mode, f);
  drawHeadphones(b, 4 + dy);
  drawGlassesOrSleepMask(b, 4 + dy, mode, f);
  drawDeskAndComputer(b, mode, f, leftDx, leftDy, rightDx, rightDy);
  if (mode === 'sleep') {
    drawZzz(b, f);
  }
}

var ROWS = ['idle', 'bone', 'sleep', 'attention'];
var IMG = SPR.layer(0).cel(0).image;
var W = SPR.width, H = SPR.height;
var sheet = new Buf(W, H);

if (typeof PROOF_MODE !== 'undefined' && PROOF_MODE) {
  drawFrame(sheet, 'idle', 0);
} else {
  for (var r = 0; r < ROWS.length; r++) {
    for (var f = 0; f < 4; f++) {
      var cell = new Buf(CW, CH);
      drawFrame(cell, ROWS[r], f);
      blit(sheet, cell, f * CW, r * CH);
    }
  }
}

IMG.putImageData(sheet.d);
SPR.save();
console.log('corgi_desk done ' + W + 'x' + H);
