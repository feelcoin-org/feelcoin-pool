#!/usr/bin/env python3
"""Safely publish the Pool header/footer from approved Pool GitHub HTML.

Default dry run is read-only. --apply creates a timestamped backup and
atomically patches the live static homepage. No mining, payout or JS changes.
"""
import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import re
import shutil
import stat
import tempfile

MARKER_START = "/* FEELCOIN_POOL_NAV_FOOTER_V1_START */"
MARKER_END = "/* FEELCOIN_POOL_NAV_FOOTER_V1_END */"
NAV = re.compile(r'<nav class="nav">[\s\S]*?</nav>')
FOOTER = re.compile(r'<footer>[\s\S]*?</footer>')
SOCIAL = re.compile(r'<div class="fc-pool-social-right">[\s\S]*?</div>')
STYLE = re.compile(
    re.escape(MARKER_START) + r"[\s\S]*?" + re.escape(MARKER_END)
)


def one(pattern, text, description):
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        raise RuntimeError(
            f"{description}: expected 1 match; got {len(matches)}"
        )
    return matches[0]


def mobile_html(text):
    opening = '<div class="fc-mobile-links">'
    # Mobile Downloads has nested <div>/<details>, but the outer wrapper
    # still ends in the exact adjacent closing tags below.
    closing = '</div></details>'
    if text.count(opening) != 1:
        raise RuntimeError("Mobile links wrapper is missing or duplicated")
    start = text.index(opening)
    end = text.find(closing, start)
    if end < 0:
        raise RuntimeError("Mobile navigation end marker missing")
    return text[start:end + len(closing)]


def inspect_old_nav(nav, mobile=False):
    necessary = (
        'href="#dashboard"', 'href="#mining"',
        '<a href="#miner">Miner</a>',
        '<a href="#faq">FAQ</a>',
        'https://feelcoin.org', 'https://explorer.feelcoin.org',
        'https://wallet.feelcoin.org', 'https://paper.feelcoin.org',
        'https://github.com/feelcoin-org/feelcoin-miner/releases/latest',
    )
    for item in necessary:
        if nav.count(item) != 1:
            raise RuntimeError(
                f"{'mobile' if mobile else 'desktop'} nav changed: "
                f"expected one {item}; got {nav.count(item)}"
            )
    if 'fc-pool-downloads' in nav or '<summary>Downloads ' in nav:
        raise RuntimeError("Found partially updated navigation")


def inspect_new_nav(nav, mobile=False):
    for item in (
        'href="#dashboard"', 'href="#mining"',
        '<a href="#miner">Miner Stats</a>',
        'https://feelcoin.org', 'https://explorer.feelcoin.org',
        'https://wallet.feelcoin.org',
        '<summary>Downloads ', 'https://api.feelcoin.org/docs',
        'https://github.com/feelcoin-org/feelcoin-miner/releases/latest',
        'https://feelcoin.org/#desktop-wallet',
        'https://feelcoin.org/#android-wallet',
        'https://paper.feelcoin.org',
    ):
        if nav.count(item) != 1:
            raise RuntimeError(
                f"Approved {'mobile' if mobile else 'desktop'} "
                f"nav missing/duplicated {item}"
            )
    if '<a href="#faq">FAQ</a>' in nav or '<a href="#miner">Miner</a>' in nav:
        raise RuntimeError("Old navigation labels remain in approved source")
    if nav.index('https://explorer.feelcoin.org') < nav.index('https://feelcoin.org'):
        raise RuntimeError("Explorer should follow Website")


def change(live, approved):
    expected_desktop = one(NAV, approved, "Approved desktop menu").group()
    expected_mobile = mobile_html(approved)
    expected_social = one(SOCIAL, approved, "Approved header socials").group()
    expected_footer = one(FOOTER, approved, "Approved explorer footer").group()
    expected_css = one(STYLE, approved, "Approved header/footer CSS").group()
    inspect_new_nav(expected_desktop)
    inspect_new_nav(expected_mobile, mobile=True)

    if MARKER_START in live or MARKER_END in live:
        if live.count(MARKER_START) != 1 or live.count(MARKER_END) != 1:
            raise RuntimeError("Partial Pool CSS update present")
        current_nav = one(NAV, live, "Current desktop menu").group()
        current_mobile = mobile_html(live)
        inspect_new_nav(current_nav)
        inspect_new_nav(current_mobile, mobile=True)
        if live.count('class="fc-pool-social-right"') != 1:
            raise RuntimeError("Expected one header social-links group")
        if '<div class="feel-social-strip">' in live:
            raise RuntimeError("Old footer social-links group remains")
        return live, False

    old_nav = one(NAV, live, "Live desktop menu").group()
    old_mobile = mobile_html(live)
    inspect_old_nav(old_nav)
    inspect_old_nav(old_mobile, mobile=True)
    if 'class="fc-pool-social-right"' in live:
        raise RuntimeError("Partial header social-links update detected")
    footer_match = one(FOOTER, live, "Live Pool footer")
    if 'id="year"' not in footer_match.group() or 'id="updated"' not in footer_match.group():
        raise RuntimeError("Live footer has unexpectedly changed")

    strip_open = '<div class="feel-social-strip">'
    if live.count(strip_open) != 1:
        raise RuntimeError("Expected one existing footer social strip")
    strip_start = live.index(strip_open)
    main_end = live.find('</main>', strip_start)
    if main_end < 0 or main_end - strip_start > 12000:
        raise RuntimeError("Unable to isolate original footer social strip")
    strip_contents = live[strip_start:main_end]
    for needle in ("Follow Feelcoin", "Follow on X", "Join Discord"):
        if needle not in strip_contents:
            raise RuntimeError("Footer social strip differed: " + needle)

    # Preserve all other content, including pool calculations/JS.
    old_runtime = live[live.rfind('</main>'):]
    result = live.replace(old_nav, expected_desktop, 1)
    result = result.replace(old_mobile, expected_mobile, 1)

    header_end = result.find("</header>")
    if header_end < 0:
        raise RuntimeError("Header closing tag missing")
    result = result[:header_end] + expected_social + "\n" + result[header_end:]

    result = FOOTER.sub(lambda _: expected_footer, result, count=1)
    # Strip is immediately after the footer and before closing <main>.
    strip_start = result.index(strip_open)
    main_end = result.find('</main>', strip_start)
    result = result[:strip_start] + result[main_end:]

    head_end = result.find("</head>")
    style_end = result.rfind("</style>", 0, head_end)
    if head_end < 0 or style_end < 0:
        raise RuntimeError("Unable to locate head stylesheet")
    result = result[:style_end] + expected_css + "\n" + result[style_end:]

    if result[result.rfind('</main>'):] != old_runtime:
        raise RuntimeError("Unexpected change to Pool JavaScript/runtime")
    if (result.count(MARKER_START) != 1
            or result.count('<summary>Downloads ') != 2
            or result.count('class="fc-pool-social-right"') != 1
            or strip_open in result):
        raise RuntimeError("Final navigation/footer checks failed")
    inspect_new_nav(one(NAV, result, "Result desktop menu").group())
    inspect_new_nav(mobile_html(result), mobile=True)
    return result, True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--live", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if not args.live.is_absolute() or args.live.name != "index.html":
        parser.error("--live must be the absolute path of Pool index.html")
    if args.live.is_symlink() or not args.live.is_file() or not args.source.is_file():
        parser.error("Files not found or live target is a symlink")
    live_text = args.live.read_text(encoding="utf-8")
    approved_text = args.source.read_text(encoding="utf-8")
    new_text, changed = change(live_text, approved_text)

    if not changed:
        print("Already deployed: Pool navigation and Explorer-style footer")
        return
    if not args.apply:
        print("Dry run OK: Pool header, Downloads, Explorer footer and socials")
        print("Mining, stats, pool payout calculations and other UI untouched")
        return

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    backup = args.live.with_name(
        args.live.name + ".before-pool-nav-footer-" + stamp
    )
    if backup.exists():
        raise RuntimeError("Backup already exists: " + str(backup))
    original_stat = args.live.stat()
    shutil.copy2(args.live, backup)
    fd, temporary = tempfile.mkstemp(
        dir=args.live.parent, prefix=".feelcoin-pool-nav-"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as out:
            out.write(new_text)
            out.flush()
            os.fsync(out.fileno())
        os.chmod(temporary, stat.S_IMODE(original_stat.st_mode))
        os.chown(temporary, original_stat.st_uid, original_stat.st_gid)
        os.replace(temporary, args.live)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print("SUCCESS: Pool header/footer updated")
    print("Backup:", backup)


if __name__ == "__main__":
    main()
