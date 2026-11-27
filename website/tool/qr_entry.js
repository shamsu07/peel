// Bundled by media.mjs into public/assets/qr.<hash>.js. Loaded only on
// desktop, to draw a QR code that opens this page on a phone.
import qrcode from 'qrcode-generator';

/** Returns an SVG string for [text], drawn with currentColor. */
export function qrSvg(text) {
  const qr = qrcode(0, 'M');
  qr.addData(text);
  qr.make();
  const n = qr.getModuleCount();
  const quiet = 2;
  const size = n + quiet * 2;
  let d = '';
  for (let r = 0; r < n; r++) {
    for (let c = 0; c < n; c++) {
      if (qr.isDark(r, c)) d += `M${c + quiet} ${r + quiet}h1v1h-1z`;
    }
  }
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size} ${size}" ` +
    `shape-rendering="crispEdges" aria-hidden="true">` +
    `<path fill="currentColor" d="${d}"/></svg>`
  );
}
