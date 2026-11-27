// Updates the site in public/ in place. No dependencies, just Node 18+.
//
//   node website/tool/build.mjs [--site https://your.domain] [--contact you@your.domain]
//
// - Writes the APK's version and size into the page: from the latest
//   GitHub release (where the download button points), or from a local
//   public/download/peel.apk and app/pubspec.yaml when there's no release.
//   Vercel runs this on every deploy, so the page matches the release.
// - Builds public/privacy.html from docs/store/privacy-policy.md.
// - Points canonical, share and structured-data links at the site URL in
//   website/site.config.json, and writes robots.txt and sitemap.xml for it.
// - Fills the policy's contact line from supportEmail in the same file.
//   While it's empty, the placeholder from the Markdown stays, highlighted.
// - Writes the JSON-LD (app, source code and FAQ) from the page itself.
//
// --site and --contact (or SITE_URL and SUPPORT_EMAIL) override the config
// and are saved back to it.
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
const configPath = join(site, 'site.config.json');

const { values: args } = parseArgs({
  options: { site: { type: 'string' }, contact: { type: 'string' } },
});

// Vercel Hobby allows 100 MB of uploaded files per CLI deploy, site included.
const APK_WARN_BYTES = 90 * 1024 * 1024;

async function main() {
  const indexPath = join(pub, 'index.html');
  let index = await readFile(indexPath, 'utf8');

  const config = JSON.parse(await readFile(configPath, 'utf8'));
  const siteArg = args.site ?? process.env.SITE_URL;
  const contactArg = args.contact ?? process.env.SUPPORT_EMAIL;
  if (siteArg) config.siteUrl = siteArg.replace(/\/+$/, '');
  if (contactArg) config.supportEmail = contactArg;
  if (siteArg || contactArg) await writeFile(configPath, JSON.stringify(config, null, 2) + '\n');

  // ---------------------------------------------------------- APK details
  const pubspec = await readFile(join(repo, 'app', 'pubspec.yaml'), 'utf8');
  let version = pubspec.match(/^version:\s*([0-9.]+)/m)?.[1];
  if (!version) throw new Error('No version: line in app/pubspec.yaml');
  index = index.replace(/(<span data-apk-version>)[^<]*(<\/span>)/g, `$1${version}$2`);

  const release = await latestRelease(config.githubRepo);
  const apk = join(pub, 'download', 'peel.apk');
  const size = release?.size ?? (await stat(apk).then((s) => s.size, () => null));
  if (release) {
    version = release.version;
    index = index.replace(/(<span data-apk-version>)[^<]*(<\/span>)/g, `$1${version}$2`);
  }
  if (size == null) {
    console.warn('! No GitHub release with peel.apk yet, and no local APK. Keeping the old size.');
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
  const wanted = config.siteUrl;
  if (!/^https:\/\/[^/]+$/.test(wanted)) throw new Error(`siteUrl must look like https://example.com, got ${wanted}`);
  index = index.split(current).join(wanted);
  if (wanted.endsWith('.example')) {
    console.warn(`! Links point at ${wanted}. Set siteUrl in site.config.json (or pass --site) once you know the domain.`);
  }

  // ---------------------------------------------------------- structured data
  const sizeText = index.match(/<span data-apk-size>([^<]*)<\/span>/)?.[1];
  index = index.replace(
    /(<script type="application\/ld\+json" id="structured-data">)[\s\S]*?(<\/script>)/,
    (_, open, close) => `${open}\n${JSON.stringify(structuredData(index, wanted, version, sizeText), null, 1)}\n${close}`,
  );

  await writeFile(indexPath, index);

  // ---------------------------------------------------------- crawling
  const today = new Date().toISOString().slice(0, 10);
  await writeFile(join(pub, 'robots.txt'), `User-agent: *\nAllow: /\n\nSitemap: ${wanted}/sitemap.xml\n`);
  await writeFile(
    join(pub, 'sitemap.xml'),
    `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>${wanted}/</loc><lastmod>${today}</lastmod></url>
  <url><loc>${wanted}/privacy</loc><lastmod>${today}</lastmod></url>
</urlset>
`,
  );

  // ---------------------------------------------------------- privacy page
  const md = await readFile(join(repo, 'docs', 'store', 'privacy-policy.md'), 'utf8');
  const contact = config.supportEmail || undefined;
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

  console.log('Updated index.html, privacy.html, site.webmanifest, robots.txt and sitemap.xml in public/.');
}

/**
 * The newest GitHub release's version and peel.apk size, or null when
 * there's none or GitHub can't be reached (the build then keeps going).
 */
async function latestRelease(repo) {
  if (!repo) return null;
  try {
    const res = await fetch(`https://api.github.com/repos/${repo}/releases/latest`, {
      headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'peel-website-build' },
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) return null;
    const json = await res.json();
    const asset = json.assets?.find((a) => a.name === 'peel.apk');
    if (!asset) return null;
    return { version: json.tag_name.replace(/^v/, ''), size: asset.size };
  } catch {
    return null;
  }
}

/**
 * JSON-LD for search engines, read from the page so it can't drift from
 * what people see: the app, its source code and the FAQ.
 */
function structuredData(index, origin, version, size) {
  const meta = (name) => decode(index.match(new RegExp(`<meta name="${name}" content="([^"]*)"`))?.[1] ?? '');
  const repoUrl = index.match(/href="([^"]+)" data-repo/)?.[1];
  if (!repoUrl) throw new Error('No GitHub link (data-repo) in index.html');
  const faq = [...index.matchAll(/<details class="qa"[^>]*>\s*<summary>([\s\S]*?)<\/summary>\s*<div class="qa-a">([\s\S]*?)<\/div>/g)].map(
    ([, q, a]) => ({
      '@type': 'Question',
      name: text(q),
      acceptedAnswer: { '@type': 'Answer', text: text(a) },
    }),
  );
  const license = 'https://opensource.org/license/mit';
  return {
    '@context': 'https://schema.org',
    '@graph': [
      { '@type': 'WebSite', '@id': `${origin}/#website`, url: `${origin}/`, name: 'Peel', inLanguage: 'en' },
      {
        '@type': 'SoftwareApplication',
        '@id': `${origin}/#app`,
        name: 'Peel: Sticker Maker',
        alternateName: 'Peel',
        description: meta('description'),
        url: `${origin}/`,
        image: `${origin}/og.png`,
        applicationCategory: 'MultimediaApplication',
        applicationSubCategory: 'Sticker maker',
        operatingSystem: 'Android 7.0 or later',
        softwareVersion: version,
        fileSize: size,
        downloadUrl: `${origin}/download/peel.apk`,
        isAccessibleForFree: true,
        offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
        license,
        sameAs: [repoUrl],
        featureList: [
          'Photo to sticker with automatic on-device cut-outs',
          'Video to moving sticker',
          'Text in two sizes',
          'Stickers with sound',
          'Named sticker packs',
          'Add to WhatsApp',
          'Light and dark mode',
        ],
      },
      {
        '@type': 'SoftwareSourceCode',
        '@id': `${origin}/#source`,
        name: 'Peel',
        codeRepository: repoUrl,
        license,
        programmingLanguage: 'Dart',
        runtimePlatform: 'Flutter',
        targetProduct: { '@id': `${origin}/#app` },
      },
      { '@type': 'FAQPage', '@id': `${origin}/#faq`, mainEntity: faq },
    ],
  };
}

const text = (html) => decode(html.replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim());
const decode = (s) =>
  s.replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>');

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
<meta name="twitter:card" content="summary_large_image">
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
