// Updates the site in public/ in place. No dependencies, just Node 18+.
//
//   node website/tool/build.mjs [--site https://your.domain] [--contact you@your.domain]
//
// - Writes the APK's version (from app/pubspec.yaml) and size (from
//   public/download/peel.apk) into the page.
// - Builds public/privacy.html from docs/store/privacy-policy.md.
// - With --site (or SITE_URL), points canonical and share links at that
//   domain. The choice is remembered in the HTML, so later runs keep it.
// - With --contact (or SUPPORT_EMAIL), fills the policy's contact line.
//   Without it, the placeholder from the Markdown stays, highlighted.
//
// build_apk.sh runs this for you after each APK build.

import { readFile, stat, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

const here = dirname(fileURLToPath(import.meta.url));
const site = join(here, '..');
const pub = join(site, 'public');
const repo = join(site, '..');

const { values: args } = parseArgs({
  options: { site: { type: 'string' }, contact: { type: 'string' } },
});

// Vercel Hobby allows 100 MB of uploaded files per CLI deploy, site included.
const APK_WARN_BYTES = 90 * 1024 * 1024;

async function main() {
  const indexPath = join(pub, 'index.html');
  let index = await readFile(indexPath, 'utf8');

  // ---------------------------------------------------------- APK details
  const pubspec = await readFile(join(repo, 'app', 'pubspec.yaml'), 'utf8');
  const version = pubspec.match(/^version:\s*([0-9.]+)/m)?.[1];
  if (!version) throw new Error('No version: line in app/pubspec.yaml');
  index = index.replace(/(<span data-apk-version>)[^<]*(<\/span>)/g, `$1${version}$2`);
  index = index.replace(/("softwareVersion":")[^"]*(")/, `$1${version}$2`);

  const apk = join(pub, 'download', 'peel.apk');
  const size = await stat(apk).then((s) => s.size, () => null);
  if (size == null) {
    console.warn('! public/download/peel.apk is missing: run tool/build_apk.sh. Keeping the old size.');
  } else {
    const mb = `${(size / 1e6).toFixed(1)} MB`;
    index = index.replace(/(<span data-apk-size>)[^<]*(<\/span>)/g, `$1${mb}$2`);
    console.log(`APK ${version}, ${mb}`);
    if (size > APK_WARN_BYTES) {
      console.warn('! The APK is close to Vercel Hobby\'s 100 MB upload limit. Host it on GitHub Releases instead (see README).');
    }
  }

  // ---------------------------------------------------------- site URL
  const current = index.match(/<link rel="canonical" href="(https?:\/\/[^/"]+)\/">/)?.[1];
  if (!current) throw new Error('No canonical link in index.html');
  const wanted = (args.site ?? process.env.SITE_URL ?? current).replace(/\/+$/, '');
  if (!/^https:\/\/[^/]+$/.test(wanted)) throw new Error(`--site must look like https://example.com, got ${wanted}`);
  index = index.split(current).join(wanted);
  if (wanted.endsWith('.example')) {
    console.warn(`! Share links point at ${wanted}. Pass --site https://your.domain once you know it.`);
  }

  await writeFile(indexPath, index);

  // ---------------------------------------------------------- privacy page
  const md = await readFile(join(repo, 'docs', 'store', 'privacy-policy.md'), 'utf8');
  const contact = args.contact ?? process.env.SUPPORT_EMAIL;
  await writeFile(join(pub, 'privacy.html'), privacyPage(index, markdown(md, contact), wanted));

  // ---------------------------------------------------------- manifest
  await writeFile(
    join(pub, 'site.webmanifest'),
    JSON.stringify(
      {
        name: 'Peel: Sticker Maker',
        short_name: 'Peel',
        start_url: '/',
        display: 'browser',
        background_color: '#F1EEE9',
        theme_color: '#F1EEE9',
        icons: [
          { src: '/icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: '/icon-512.png', sizes: '512x512', type: 'image/png' },
        ],
      },
      null,
      2,
    ) + '\n',
  );

  console.log('Updated public/index.html, public/privacy.html and public/site.webmanifest.');
}

/** The privacy page: the home page's head and styles, the policy as the body. */
function privacyPage(index, body, origin) {
  const shared = index.match(/<!-- shared-head -->[\s\S]*?<!-- \/shared-head -->/)?.[0];
  if (!shared) throw new Error('No shared-head block in index.html');
  const wordmark = index.match(/<img src="(\/assets\/img\/wordmark\.[0-9a-f]{8}\.svg)"/)?.[1];
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Privacy policy · Peel</title>
<meta name="description" content="How Peel handles your photos, videos and sounds: everything stays on your phone.">
<link rel="canonical" href="${origin}/privacy">
${shared}
<meta property="og:type" content="article">
<meta property="og:site_name" content="Peel">
<meta property="og:title" content="Peel privacy policy">
<meta property="og:url" content="${origin}/privacy">
<meta property="og:image" content="${origin}/og.png">
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="wrap top">
  <a class="brand" href="/"><img src="${wordmark}" width="112" height="62" alt="Peel, home"></a>
</header>
<main id="main" class="wrap">
  <article class="doc">
${body}
  </article>
  <a class="back" href="/"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M15 5l-7 7 7 7"/></svg>Back to Peel</a>
</main>
<footer class="wrap foot">
  <p>Peel isn’t made by or affiliated with WhatsApp or&nbsp;Meta.</p>
  <p>© 2026 Peel</p>
</footer>
</body>
</html>
`;
}

/**
 * Just enough Markdown for the policy: headings, paragraphs, lists,
 * **bold**, *italic* and [links](url). `[like this]` with no URL is a
 * placeholder and gets highlighted, unless --contact fills it.
 */
function markdown(src, contact) {
  const out = [];
  let para = [];
  let list = null;

  const flushPara = () => {
    if (para.length) out.push(`<p>${inline(para.join(' '), contact)}</p>`);
    para = [];
  };
  const flushList = () => {
    if (list) out.push(`<ul>\n${list.map((li) => `<li>${inline(li, contact)}</li>`).join('\n')}\n</ul>`);
    list = null;
  };

  for (const raw of src.split('\n')) {
    const line = raw.trimEnd();
    let m;
    if (!line.trim()) {
      flushPara();
      flushList();
    } else if ((m = line.match(/^(#{1,3})\s+(.*)$/))) {
      flushPara();
      flushList();
      const level = m[1].length;
      out.push(`<h${level}>${inline(m[2], contact)}</h${level}>`);
    } else if ((m = line.match(/^[-*]\s+(.*)$/))) {
      flushPara();
      (list ??= []).push(m[1]);
    } else if (list && /^\s+\S/.test(line)) {
      list[list.length - 1] += ' ' + line.trim();
    } else {
      flushList();
      para.push(line.trim());
    }
  }
  flushPara();
  flushList();
  return out.map((l) => `    ${l}`).join('\n');
}

function inline(text, contact) {
  return escapeHtml(text)
    .replace(/\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g, '<a href="$2">$1</a>')
    .replace(/\[([^\]]+)\](?!\()/g, (_, label) =>
      contact
        ? `<a href="mailto:${escapeHtml(contact)}">${escapeHtml(contact)}</a>`
        : `<mark>[${label}]</mark>`,
    )
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\*([^*]+)\*/g, '<em>$1</em>');
}

function escapeHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

await main();
