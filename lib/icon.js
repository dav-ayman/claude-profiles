// claude-profiles icon renderer (JavaScript for Automation, runs on stock macOS).
//
// usage: osascript -l JavaScript icon.js <app-path> <out.png> <letter> <RRGGBB> <bleed|tile>
//
// Renders the icon macOS shows for <app-path> at 1024x1024 and stamps a round
// letter badge on it.
//   bleed: crop to the opaque tile and stretch it edge to edge. macOS 26+ masks
//          full-bleed artwork itself; anything else gets a grey platter.
//   tile:  keep the original tile shape (macOS 13-15).

ObjC.import('AppKit');

var N = 1024;

function bitmap() {
  return $.NSBitmapImageRep.alloc.initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(
    null, N, N, 8, 4, true, false, $.NSDeviceRGBColorSpace, 0, 0);
}

function withContext(rep, draw) {
  $.NSGraphicsContext.saveGraphicsState;
  $.NSGraphicsContext.setCurrentContext($.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep));
  try { draw(); } finally { $.NSGraphicsContext.restoreGraphicsState; }
}

function opaque(rep, x, y) { return rep.colorAtXY(x, y).alphaComponent > 0.5; }

// Extent of the opaque tile along the centre row and column (bitmap y grows down).
function tileBounds(rep) {
  var mid = N / 2, minX = N, maxX = -1, minY = N, maxY = -1, i;
  for (i = 0; i < N; i++) {
    if (opaque(rep, i, mid)) { if (i < minX) minX = i; if (i > maxX) maxX = i; }
    if (opaque(rep, mid, i)) { if (i < minY) minY = i; if (i > maxY) maxY = i; }
  }
  if (maxX < 0 || maxY < 0) return { minX: 0, maxX: N - 1, minY: 0, maxY: N - 1 };
  return { minX: minX, maxX: maxX, minY: minY, maxY: maxY };
}

function hexColor(hex) {
  var v = parseInt(hex, 16);
  return $.NSColor.colorWithSRGBRedGreenBlueAlpha(((v >> 16) & 255) / 255, ((v >> 8) & 255) / 255, (v & 255) / 255, 1);
}

function drawBadge(tileX, tileY, tileW, letter, color) {
  var d = 0.39 * tileW, inset = 0.093 * tileW;
  var rect = $.NSMakeRect(tileX + tileW - d - inset, tileY + inset, d, d);
  var circle = $.NSBezierPath.bezierPathWithOvalInRect(rect);
  color.setFill; circle.fill;
  $.NSColor.whiteColor.setStroke; circle.setLineWidth(0.075 * d); circle.stroke;

  var attrs = $.NSMutableDictionary.alloc.init;
  attrs.setObjectForKey($.NSFont.systemFontOfSizeWeight(0.675 * d, 0.62), $.NSFontAttributeName);
  attrs.setObjectForKey($.NSColor.whiteColor, $.NSForegroundColorAttributeName);
  var text = $.NSString.alloc.initWithUTF8String(letter);
  var size = text.sizeWithAttributes(attrs);
  text.drawAtPointWithAttributes($.NSMakePoint(
    rect.origin.x + (d - size.width) / 2,
    rect.origin.y + (d - size.height) / 2 + 0.015 * d), attrs);
}

function run(argv) {
  if (argv.length !== 5) throw new Error('usage: icon.js <app> <out.png> <letter> <RRGGBB> <bleed|tile>');
  var app = argv[0], out = argv[1], letter = argv[2], hex = argv[3], style = argv[4];
  if (!/^[A-Za-z0-9]$/.test(letter)) throw new Error('letter must be one character A-Z or 0-9');
  if (!/^[0-9A-Fa-f]{6}$/.test(hex)) throw new Error('color must be RRGGBB hex');
  if (style !== 'bleed' && style !== 'tile') throw new Error('style must be bleed or tile');
  if (!$.NSFileManager.defaultManager.fileExistsAtPath(app)) throw new Error('not found: ' + app);

  var src = bitmap();
  withContext(src, function () {
    $.NSWorkspace.sharedWorkspace.iconForFile(app).drawInRect($.NSMakeRect(0, 0, N, N));
  });
  var b = tileBounds(src);
  var tileW = b.maxX - b.minX + 1, tileH = b.maxY - b.minY + 1;

  var out_rep = bitmap();
  withContext(out_rep, function () {
    if (style === 'bleed') {
      var srcImg = $.NSImage.alloc.initWithSize($.NSMakeSize(N, N));
      srcImg.addRepresentation(src);
      src.colorAtXY(Math.floor(N / 2), b.minY + 4).setFill;
      $.NSRectFill($.NSMakeRect(0, 0, N, N));
      srcImg.drawInRectFromRectOperationFraction(
        $.NSMakeRect(0, 0, N, N),
        $.NSMakeRect(b.minX, N - 1 - b.maxY, tileW, tileH),
        $.NSCompositingOperationSourceOver, 1);
      drawBadge(0, 0, N, letter.toUpperCase(), hexColor(hex));
    } else {
      $.NSWorkspace.sharedWorkspace.iconForFile(app).drawInRect($.NSMakeRect(0, 0, N, N));
      drawBadge(b.minX, N - 1 - b.maxY, tileW, letter.toUpperCase(), hexColor(hex));
    }
  });

  var png = out_rep.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $.NSDictionary.dictionary);
  if (!png.writeToFileAtomically(out, true)) throw new Error('could not write ' + out);
  return out;
}
