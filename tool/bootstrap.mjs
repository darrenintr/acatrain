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

if (missing.length === 0) {
  console.log('Requested platform runners are already present; nothing was regenerated.');
} else {
  console.log(`Generated missing platform runners: ${missing.join(', ')}`);
}
