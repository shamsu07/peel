// Makes the site's images, fonts and icons from the app's own assets.
//
//   cd website/tool && npm install && node media.mjs
//
// Only needed when the app's stickers, logo or fonts change. Output goes to
// website/public and is committed. Files under public/assets get a content
// hash in their name (so Vercel can cache them for a year), and every
// reference to them in public/*.html is updated to the new name.

import { createHash } from 'node:crypto';
import { mkdir, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as esbuild from 'esbuild';
import sharp from 'sharp';
import subsetFont from 'subset-font';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const app = join(root, 'app');
const brand = join(root, 'design', 'brand');
const pub = join(here, '..', 'public');
const assets = join(pub, 'assets');

const PAPER = '#F1EEE9';

/** logical path under assets/ -> hashed path under assets/ */
const manifest = {};

const hash = (buf) => createHash('sha256').update(buf).digest('hex').slice(0, 8);

async function emit(logical, buf) {
  const dot = logical.lastIndexOf('.');
  const hashed = `${logical.slice(0, dot)}.${hash(buf)}${logical.slice(dot)}`;
  await mkdir(dirname(join(assets, hashed)), { recursive: true });
  await writeFile(join(assets, hashed), buf);
  manifest[logical] = hashed;
}

// ---------------------------------------------------------------- fonts

// Latin text plus the punctuation the copy uses.
const latin =
  Array.from({ length: 0x7f - 0x20 }, (_, i) => String.fromCharCode(0x20 + i)).join('') +
  Array.from({ length: 0x100 - 0xa0 }, (_, i) => String.fromCharCode(0xa0 + i)).join('') +
  '‘’“”–—•…→←↓·©™€';

const fonts = [
  ['InterTight-Regular.ttf', 'fonts/inter-tight-400.woff2'],
  ['InterTight-Bold.ttf', 'fonts/inter-tight-700.woff2'],
  ['InterTight-ExtraBold.ttf', 'fonts/inter-tight-800.woff2'],
  ['InstrumentSerif-Italic.ttf', 'fonts/instrument-serif-italic.woff2'],
  ['TitanOne-Regular.ttf', 'fonts/titan-one.woff2'],
  ['LuckiestGuy-Regular.ttf', 'fonts/luckiest-guy.woff2'],
  ['Baloo2-ExtraBold.ttf', 'fonts/baloo-2-800.woff2'],
];

// ---------------------------------------------------------------- images

// Stickers from the app, each as AVIF and WebP at two widths.
const stickers = [
  'home_badge', 'home_star', 'home_flame', 'brb', 'cat', 'dog', 'lol_same',
  'nope', 'on_my_way', 'running_late', 'googly_eyes', 'heart_ok', 'cloud', 'star',
];
const stickerWidths = [200, 400];

async function main() {
  await rm(assets, { recursive: true, force: true });

  for (const [src, out] of fonts) {
    const ttf = await readFile(join(app, 'assets', 'google_fonts', src));
    await emit(out, Buffer.from(await subsetFont(ttf, latin, { targetFormat: 'woff2' })));
  }

  for (const name of stickers) {
    const src = join(app, 'assets', 'stickers', `${name}.webp`);
    const { width } = await sharp(src).metadata();
    for (const w of stickerWidths) {
      const size = Math.min(w, width);
      const img = sharp(src).resize({ width: size });
      await emit(`img/${name}-${w}.avif`, await img.clone().avif({ quality: 60, effort: 9 }).toBuffer());
      await emit(`img/${name}-${w}.webp`, await img.clone().webp({ quality: 82, alphaQuality: 90, effort: 6 }).toBuffer());
    }
  }

  // The wordmark, as drawn for the app.
  const wordmark = await readFile(join(brand, 'source', 'wordmark-tight.svg'));
  await emit('img/wordmark.svg', wordmark);

  // QR code drawer, desktop only.
  const qr = await esbuild.build({
    entryPoints: [join(here, 'qr_entry.js')],
    bundle: true,
    minify: true,
    format: 'esm',
    write: false,
    legalComments: 'inline',
  });
  await emit('qr.js', Buffer.from(qr.outputFiles[0].contents));

  // ------------------------------------------------------------ icons
  const iconSquare = join(brand, 'png', 'icon-1024.png');
  const iconRounded = join(brand, 'png', 'icon-1024-rounded.png');

  await writeFile(join(pub, 'icon.svg'), await readFile(join(brand, 'source', 'icon-1024-rounded.svg')));
  await sharp(iconSquare).resize(180).png().toFile(join(pub, 'apple-touch-icon.png'));
  await sharp(iconRounded).resize(192).png().toFile(join(pub, 'icon-192.png'));
  await sharp(iconRounded).resize(512).png().toFile(join(pub, 'icon-512.png'));
  await writeFile(join(pub, 'favicon.ico'), ico(await sharp(iconRounded).resize(32).png().toBuffer(), 32));

  // ------------------------------------------------------------ share image
  // 1200 × 630: the wordmark on paper, with a few stickers around it.
  const W = 1200;
  const H = 630;
  const place = async (file, size, left, top, angle = 0) => ({
    input: await sharp(file)
      .resize(size, size, { fit: 'contain', background: '#0000' })
      .rotate(angle, { background: '#0000' })
      .png()
      .toBuffer(),
    left,
    top,
  });
  const sticker = (n) => join(app, 'assets', 'stickers', `${n}.webp`);
  const mark = await sharp(wordmark, { density: 220 }).resize({ width: 760 }).png().toBuffer();
  const markMeta = await sharp(mark).metadata();
  await sharp({ create: { width: W, height: H, channels: 4, background: PAPER } })
    .composite([
      await place(sticker('home_badge'), 210, 40, 30, -8),
      await place(sticker('lol_same'), 230, 930, 40, 6),
      await place(sticker('cat'), 190, 70, 400, 4),
      await place(sticker('home_flame'), 170, 980, 410, -6),
      await place(sticker('on_my_way'), 180, 760, 470, -4),
      { input: mark, left: Math.round((W - markMeta.width) / 2), top: Math.round((H - markMeta.height) / 2) - 20 },
    ])
    .png({ compressionLevel: 9 })
    .toFile(join(pub, 'og.png'));

  // ------------------------------------------------------------ references
  for (const file of (await readdir(pub)).filter((f) => f.endsWith('.html'))) {
    const path = join(pub, file);
    let html = await readFile(path, 'utf8');
    for (const [logical, hashed] of Object.entries(manifest)) {
      const dot = logical.lastIndexOf('.');
      const re = new RegExp(
        `/assets/${esc(logical.slice(0, dot))}\\.[0-9a-f]{8}${esc(logical.slice(dot))}`,
        'g',
      );
      html = html.replace(re, `/assets/${hashed}`);
    }
    await writeFile(path, html);
  }

  await writeFile(join(here, 'assets.json'), JSON.stringify(manifest, null, 2) + '\n');
  console.log(`Wrote ${Object.keys(manifest).length} assets. See tool/assets.json.`);
}

const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** A one-image .ico that wraps a PNG (supported by every current browser). */
function ico(png, size) {
  const header = Buffer.alloc(6 + 16);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2); // icon
  header.writeUInt16LE(1, 4); // one image
  header.writeUInt8(size, 6);
  header.writeUInt8(size, 7);
  header.writeUInt8(0, 8); // no palette
  header.writeUInt8(0, 9);
  header.writeUInt16LE(1, 10); // planes
  header.writeUInt16LE(32, 12); // bits per pixel
  header.writeUInt32LE(png.length, 14);
  header.writeUInt32LE(22, 18); // offset
  return Buffer.concat([header, png]);
}

await main();
