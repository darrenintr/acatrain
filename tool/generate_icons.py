#!/usr/bin/env python3
"""Renders the Acatrain app icon for every platform from one design.

The design mirrors the in-app logo: a cookie-shaped badge (the
`ExpressiveShape.cookie9` curve from lib/expressive.dart) carrying the
rounded "school" cap, on an Evergreen field.

Committed outputs (Android and iOS runners, packaging/linux, and
packaging/icons for the runners tool/bootstrap.mjs generates) are all
written by this script, so re-run it after changing the design:

    pip install pillow cairosvg
    python3 tool/generate_icons.py
"""

import io
import json
import math
import os
import shutil

import cairosvg
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Evergreen palette (lib/main.dart light scheme).
FIELD_TOP = '#4A8A69'
FIELD_BOTTOM = '#1F4A35'
BADGE = '#B8F0CF'
BADGE_SHADE = '#9DD4B4'
CAP = '#0E3A26'

# Material Icons Round "school", 24x24 viewBox.
CAP_PATH = (
    'M5 13.18v2.81c0 .73.4 1.41 1.04 1.76l5 2.73c.6.33 1.32.33 1.92 0l5-2.73'
    'c.64-.35 1.04-1.03 1.04-1.76v-2.81l-6.04 3.3c-.6.33-1.32.33-1.92 0L5 13.18z'
    'm6.04-9.66l-8.43 4.6c-.69.38-.69 1.38 0 1.76l8.43 4.6c.6.33 1.32.33 1.92 0'
    'L21 10.09V16c0 .55.45 1 1 1s1-.45 1-1V9.59c0-.37-.2-.7-.52-.88l-9.52-5.19'
    'c-.6-.32-1.32-.32-1.92 0z'
)


def cookie_path(cx, cy, radius, n=9, a=0.075, samples=360):
    points = []
    for i in range(samples):
        theta = 2 * math.pi * i / samples
        r = radius * (1 + a * math.cos(n * theta)) / (1 + a)
        angle = theta - math.pi / 2
        points.append(f'{cx + r * math.cos(angle):.2f},{cy + r * math.sin(angle):.2f}')
    return 'M' + ' L'.join(points) + ' Z'


def mark(scale, cap_color=CAP, badge_color=BADGE, shadow=True):
    """The badge + cap, centred in a 1024 box, [scale] = badge diameter / 1024."""
    radius = 512 * scale
    cap_size = radius * 1.16
    offset = 512 - cap_size / 2
    parts = []
    if shadow:
        parts.append(
            f'<path d="{cookie_path(512, 530, radius)}" fill="#000" opacity="0.18" '
            'filter="url(#soft)"/>'
        )
    parts.append(f'<path d="{cookie_path(512, 512, radius)}" fill="url(#badge)"/>')
    parts.append(
        f'<g transform="translate({offset:.2f} {offset + radius * 0.02:.2f}) '
        f'scale({cap_size / 24:.4f})"><path d="{CAP_PATH}" fill="{cap_color}"/></g>'
    )
    defs = (
        '<defs>'
        '<filter id="soft" x="-20%" y="-20%" width="140%" height="140%">'
        '<feGaussianBlur stdDeviation="18"/></filter>'
        '<linearGradient id="badge" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{badge_color}"/>'
        f'<stop offset="1" stop-color="{BADGE_SHADE if badge_color == BADGE else badge_color}"/>'
        '</linearGradient></defs>'
    )
    return defs + ''.join(parts)


FIELD_DEFS = (
    '<defs><linearGradient id="field" x1="0" y1="0" x2="0.35" y2="1">'
    f'<stop offset="0" stop-color="{FIELD_TOP}"/>'
    f'<stop offset="1" stop-color="{FIELD_BOTTOM}"/>'
    '</linearGradient>'
    '<radialGradient id="glow" cx="0.3" cy="0.12" r="0.8">'
    '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.22"/>'
    '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>'
    '</radialGradient></defs>'
)


def svg(body):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" '
        f'width="1024" height="1024">{body}</svg>'
    )


def full_bleed():
    """Square, opaque: iOS, Android legacy, web maskable, Windows tiles."""
    return svg(
        FIELD_DEFS
        + '<rect width="1024" height="1024" fill="url(#field)"/>'
        + '<rect width="1024" height="1024" fill="url(#glow)"/>'
        + mark(0.60)
    )


def rounded(inset=0, corner=230):
    """Rounded-square tile: Linux, Windows, web favicon, macOS body."""
    size = 1024 - inset * 2
    inner = (
        f'<rect x="{inset}" y="{inset}" width="{size}" height="{size}" '
        f'rx="{corner}" fill="url(#field)"/>'
        f'<rect x="{inset}" y="{inset}" width="{size}" height="{size}" '
        f'rx="{corner}" fill="url(#glow)"/>'
    )
    scale = 0.60 * size / 1024
    return svg(FIELD_DEFS + inner + mark(scale))


def macos():
    """Big Sur style: 824px body on a 1024 canvas with a drop shadow."""
    inset = 100
    size = 824
    return svg(
        FIELD_DEFS
        + '<defs><filter id="drop" x="-10%" y="-10%" width="120%" height="130%">'
        '<feGaussianBlur stdDeviation="14"/></filter></defs>'
        f'<rect x="{inset}" y="{inset + 12}" width="{size}" height="{size}" rx="185" '
        'fill="#000" opacity="0.28" filter="url(#drop)"/>'
        f'<rect x="{inset}" y="{inset}" width="{size}" height="{size}" rx="185" fill="url(#field)"/>'
        f'<rect x="{inset}" y="{inset}" width="{size}" height="{size}" rx="185" fill="url(#glow)"/>'
        + mark(0.60 * size / 1024)
    )


def adaptive_foreground():
    """Android adaptive foreground: mark inside the 66/108 safe zone."""
    return svg(mark(0.60 * 66 / 108 * 1.02))


def monochrome_parts():
    """Android 13 themed icon: the badge silhouette and the cap to cut out of
    it (combined in [render_monochrome]; the SVG renderer ignores masks)."""
    radius = 512 * 0.60 * 66 / 108 * 1.02
    cap_size = radius * 1.16
    offset = 512 - cap_size / 2
    badge = svg(f'<path d="{cookie_path(512, 512, radius)}" fill="#000"/>')
    cap = svg(
        f'<g transform="translate({offset:.2f} {offset + radius * 0.02:.2f}) '
        f'scale({cap_size / 24:.4f})"><path d="{CAP_PATH}" fill="#000"/></g>'
    )
    return badge, cap


def render_monochrome(size):
    badge_svg, cap_svg = monochrome_parts()
    badge, cap = render(badge_svg, size), render(cap_svg, size)
    alpha = badge.getchannel('A')
    cut = cap.getchannel('A')
    alpha = Image.composite(Image.new('L', alpha.size, 0), alpha, cut)
    out = Image.new('RGBA', badge.size, (0, 0, 0, 0))
    out.putalpha(alpha)
    return out


def render(svg_text, size, opaque=False):
    png = cairosvg.svg2png(bytestring=svg_text.encode(), output_width=size, output_height=size)
    image = Image.open(io.BytesIO(png)).convert('RGBA')
    if opaque:
        background = Image.new('RGBA', image.size, FIELD_BOTTOM)
        image = Image.alpha_composite(background, image).convert('RGB')
    return image


def save(image, *path):
    target = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    image.save(target, optimize=True)
    return target


def write(text, *path):
    target = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, 'w', encoding='utf-8') as f:
        f.write(text)


def android():
    res = ('android', 'app', 'src', 'main', 'res')
    densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    square, tile = full_bleed(), rounded(inset=0, corner=512 * 0.36)
    circle = svg(
        FIELD_DEFS
        + '<circle cx="512" cy="512" r="512" fill="url(#field)"/>'
        + '<circle cx="512" cy="512" r="512" fill="url(#glow)"/>'
        + mark(0.60)
    )
    fg = adaptive_foreground()
    for name, factor in densities.items():
        save(render(tile, round(48 * factor)), *res, f'mipmap-{name}', 'ic_launcher.png')
        save(render(circle, round(48 * factor)), *res, f'mipmap-{name}', 'ic_launcher_round.png')
        save(render(fg, round(108 * factor)), *res, f'mipmap-{name}', 'ic_launcher_foreground.png')
        save(render_monochrome(round(108 * factor)), *res, f'mipmap-{name}', 'ic_launcher_monochrome.png')
    adaptive = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@drawable/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
        '</adaptive-icon>\n'
    )
    write(adaptive, *res, 'mipmap-anydpi-v26', 'ic_launcher.xml')
    write(adaptive, *res, 'mipmap-anydpi-v26', 'ic_launcher_round.xml')
    write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<shape xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <gradient\n'
        '        android:angle="270"\n'
        f'        android:startColor="{FIELD_TOP}"\n'
        f'        android:endColor="{FIELD_BOTTOM}"\n'
        '        android:type="linear" />\n'
        '</shape>\n',
        *res, 'drawable', 'ic_launcher_background.xml',
    )
    save(render(square, 512, opaque=True), 'packaging', 'icons', 'android', 'play_store_512.png')


def ios():
    folder = ('ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    with open(os.path.join(ROOT, *folder, 'Contents.json'), encoding='utf-8') as f:
        contents = json.load(f)
    art = full_bleed()
    for entry in contents['images']:
        if 'filename' not in entry:
            continue
        points = float(entry['size'].split('x')[0])
        scale = int(entry['scale'].rstrip('x'))
        # App Store icons must not have an alpha channel.
        save(render(art, round(points * scale), opaque=True), *folder, entry['filename'])


def web():
    out = ('packaging', 'icons', 'web')
    tile = rounded(inset=40, corner=220)
    square = full_bleed()
    save(render(tile, 32), *out, 'favicon.png')
    save(render(tile, 192), *out, 'icons', 'Icon-192.png')
    save(render(tile, 512), *out, 'icons', 'Icon-512.png')
    save(render(square, 192, opaque=True), *out, 'icons', 'Icon-maskable-192.png')
    save(render(square, 512, opaque=True), *out, 'icons', 'Icon-maskable-512.png')
    save(render(square, 180, opaque=True), *out, 'icons', 'apple-touch-icon.png')


def macos_icons():
    out = ('packaging', 'icons', 'macos', 'AppIcon.appiconset')
    art = macos()
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save(render(art, size), *out, f'app_icon_{size}.png')


def windows():
    out = os.path.join(ROOT, 'packaging', 'icons', 'windows', 'app_icon.ico')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    art = rounded(inset=24, corner=200)
    sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
    frames = [render(art, s) for s in sizes]
    frames[-1].save(out, format='ICO', sizes=[(s, s) for s in sizes], append_images=frames[:-1])


def linux():
    art = rounded(inset=64, corner=210)
    write(art + '\n', 'packaging', 'linux', 'io.github.darrenintr.acatrain.svg')


def master():
    write(full_bleed() + '\n', 'packaging', 'icons', 'acatrain-icon.svg')
    save(render(full_bleed(), 1024, opaque=True), 'packaging', 'icons', 'acatrain-icon-1024.png')


if __name__ == '__main__':
    shutil.rmtree(os.path.join(ROOT, 'packaging', 'icons'), ignore_errors=True)
    master()
    android()
    ios()
    web()
    macos_icons()
    windows()
    linux()
    print('Icons written for Android, iOS, Web, macOS, Windows and Linux.')
