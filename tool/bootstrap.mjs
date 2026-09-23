import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const supported = ['android', 'ios', 'web', 'linux', 'windows', 'macos'];
const requested = process.argv.find(a => a.startsWith('--platforms='))?.split('=')[1]?.split(',') ?? supported;

if (requested.some(p => !supported.includes(p))) throw new Error('Unsupported platform');
if (!fs.existsSync('pubspec.yaml')) throw new Error('Run this script from the repository root');

const missing = requested.filter(platform => !fs.existsSync(platform));

if (missing.length > 0) {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'acatrain-'));
  try {
    const target = path.join(temp, 'acatrain');
    const run = spawnSync(
      process.platform === 'win32' ? 'flutter.bat' : 'flutter',
      [
        'create',
        '--empty',
        '--no-pub',
        '--org',
        'io.github.darrenintr',
        '--project-name',
        'acatrain',
        `--platforms=${missing.join(',')}`,
        target,
      ],
      { stdio: 'inherit', shell: process.platform === 'win32' },
    );
    if (run.error) throw run.error;
    if (run.status !== 0) throw new Error('flutter create failed');

    for (const platform of missing) {
      const source = path.join(target, platform);
      if (fs.existsSync(source)) fs.cpSync(source, platform, { recursive: true });
    }
  } finally {
    fs.rmSync(temp, { recursive: true, force: true });
  }
}

if (requested.includes('android')) {
  const manifest = 'android/app/src/main/AndroidManifest.xml';
  if (fs.existsSync(manifest)) {
    let xml = fs.readFileSync(manifest, 'utf8');
    if (!xml.includes('android.permission.INTERNET')) {
      xml = xml.replace(
        /(<manifest[^>]*>)/,
        '$1\n    <uses-permission android:name="android.permission.INTERNET"/>',
      );
      fs.writeFileSync(manifest, xml);
    }
  }
}

if (requested.includes('ios')) {
  const iosInfo = 'ios/Runner/Info.plist';
  if (fs.existsSync(iosInfo)) {
    let xml = fs.readFileSync(iosInfo, 'utf8');
    if (!xml.includes('CADisableMinimumFrameDurationOnPhone')) {
      xml = xml.replace(
        '</dict>',
        '    <key>CADisableMinimumFrameDurationOnPhone</key>\n    <true/>\n</dict>',
      );
      fs.writeFileSync(iosInfo, xml);
    }
  }
}

if (requested.includes('macos')) {
  for (const name of ['DebugProfile', 'Release']) {
    const file = `macos/Runner/${name}.entitlements`;
    if (fs.existsSync(file)) {
      let xml = fs.readFileSync(file, 'utf8');
      if (!xml.includes('com.apple.security.network.client')) {
        xml = xml.replace(
          '</dict>',
          '    <key>com.apple.security.network.client</key>\n    <true/>\n</dict>',
        );
        fs.writeFileSync(file, xml);
      }
    }
  }
}

// App icons, names and launch colours. Only freshly generated runners are
// branded unless --icons is passed, so an existing runner is never changed
// behind your back. Re-render the icons with tool/generate_icons.py.
const refreshIcons = process.argv.includes('--icons');
const brand = refreshIcons ? requested : missing;
const icons = 'packaging/icons';
const missingBrandAssets = new Set();
const copyIcon = (from, to) => {
  if (!fs.existsSync(path.dirname(to))) return false;
  const source = path.join(icons, from);
  if (!fs.existsSync(source)) {
    if (refreshIcons) {
      throw new Error(
        `Missing branding asset: ${source}. Run python3 tool/generate_icons.py first.`,
      );
    }
    missingBrandAssets.add(from);
    return false;
  }
  fs.copyFileSync(source, to);
  return true;
};
const patch = (file, edit) => {
  if (!fs.existsSync(file)) return;
  const before = fs.readFileSync(file, 'utf8');
  const after = edit(before);
  if (after !== before) fs.writeFileSync(file, after);
};

if (brand.includes('web') && fs.existsSync('web')) {
  for (const name of ['Icon-192.png', 'Icon-512.png', 'Icon-maskable-192.png', 'Icon-maskable-512.png', 'apple-touch-icon.png']) {
    fs.mkdirSync('web/icons', { recursive: true });
    copyIcon(`web/icons/${name}`, `web/icons/${name}`);
  }
  copyIcon('web/favicon.png', 'web/favicon.png');
  patch('web/manifest.json', json => {
    const manifest = JSON.parse(json);
    Object.assign(manifest, {
      name: 'Acatrain',
      short_name: 'Acatrain',
      description: 'Offline-first study sets.',
      background_color: '#F6FBF4',
      theme_color: '#36684F',
    });
    return `${JSON.stringify(manifest, null, 4)}\n`;
  });
  patch('web/index.html', html => {
    html = html
      .replace(/content="acatrain"/g, 'content="Acatrain"')
      .replace('<title>acatrain</title>', '<title>Acatrain</title>')
      .replace('href="icons/Icon-192.png"', 'href="icons/apple-touch-icon.png"');
    if (!html.includes('acatrain-launch-surface')) {
      // Paint the app surface before Flutter boots so the launch animation
      // starts from the same colour instead of a white flash.
      html = html.replace(
        '</head>',
        '  <meta name="theme-color" content="#36684F">\n' +
          '  <style id="acatrain-launch-surface">\n' +
          '    html, body { background: #F6FBF4; }\n' +
          '    @media (prefers-color-scheme: dark) { html, body { background: #0F1511; } }\n' +
          '  </style>\n' +
          '</head>',
      );
    }
    return html;
  });
}

if (brand.includes('macos')) {
  const target = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
  for (const size of [16, 32, 64, 128, 256, 512, 1024]) {
    copyIcon(`macos/AppIcon.appiconset/app_icon_${size}.png`, `${target}/app_icon_${size}.png`);
  }
}

if (brand.includes('windows')) {
  copyIcon('windows/app_icon.ico', 'windows/runner/resources/app_icon.ico');
  patch('windows/runner/main.cpp', text => text.replace('L"acatrain"', 'L"Acatrain"'));
}

if (brand.includes('linux')) {
  patch('linux/runner/my_application.cc', text =>
    text.replace(/set_title\((\w+), "acatrain"\)/g, 'set_title($1, "Acatrain")'),
  );
}

if (missingBrandAssets.size > 0) {
  console.warn(
    `Branding assets missing; kept Flutter defaults for: ${[...missingBrandAssets].join(', ')}`,
  );
  console.warn(
    'Run python3 tool/generate_icons.py and commit packaging outputs to restore custom icons.',
  );
}

if (missing.length === 0) {
  console.log('Requested platform runners are already present; nothing was regenerated.');
} else {
  console.log(`Generated missing platform runners: ${missing.join(', ')}`);
}
