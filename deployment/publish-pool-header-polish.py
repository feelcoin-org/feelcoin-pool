#!/usr/bin/env python3
"""Safely publish Pool header fixes without replacing unrelated live HTML.

Fixes Downloads popup layering, increases desktop nav text to 14px,
moves existing Discord/X/Telegram links directly after GitHub,
and leaves Pool Online rightmost. Footer stays Explorer-style.
By default: dry run. --apply creates a backup and atomically edits the page.
"""
import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import re
import shutil
import stat
import tempfile

CSS_START = "/* FEELCOIN_POOL_HEADER_POLISH_V2_START */"
CSS_END = "/* FEELCOIN_POOL_HEADER_POLISH_V2_END */"
STYLE = re.compile(re.escape(CSS_START) + r".*?" + re.escape(CSS_END), re.S)
HEADER = re.compile(r'<header class="topbar">.*?</header>', re.S)
NAV = re.compile(r'<nav class="nav">.*?</nav>', re.S)
SOCIAL = re.compile(r'<div class="fc-pool-social-right">.*?</div>', re.S)
FOOTER = re.compile(r'<footer>.*?</footer>', re.S)


def one(pattern, text, what):
    hits = list(pattern.finditer(text))
    if len(hits) != 1:
        raise RuntimeError(f"{what}: expected exactly one block, found {len(hits)}")
    return hits[0]


def verify_header(header, what, expected_new):
    nav = one(NAV, header, f"{what} desktop navigation").group()
    social = one(SOCIAL, header, f"{what} social buttons")
    if expected_new:
        if social.start() > header.index("</nav>"):
            raise RuntimeError(what + ": social links aren't inside main navigation")
        if social.start() < header.index("GitHub"):
            raise RuntimeError(what + ": social links must follow GitHub")
        if header.index('class="status"') < social.end():
            raise RuntimeError(what + ": Pool Online must follow social buttons")
    else:
        if social.start() < header.index("</nav>"):
            raise RuntimeError(what + ": social buttons already inside nav, but new CSS is absent")
        if social.start() < header.index('class="status"'):
            raise RuntimeError(what + ": legacy header layout unrecognized")
    for title in ('Miner Stats', 'Pool Info', 'API Docs', 'Downloads', 'Explorer'):
        if title not in nav:
            raise RuntimeError(f"{what}: expected nav item {title} missing")
    for href in ('https://discord.com/invite/2sx7Q8yAR',
                 'https://x.com/feelcoin_org',
                 'https://t.me/feelcoin_community'):
        if social.group().count(href) != 1:
            raise RuntimeError(f"{what}: social href missing/duplicated: {href}")


def patch(live, approved):
    css = one(STYLE, approved, "approved GitHub CSS").group()
    source_header = one(HEADER, approved, "approved GitHub header").group()
    verify_header(source_header, "approved", True)
    live_header = one(HEADER, live, "live Pool header").group()
    source_footer = one(FOOTER, approved, "approved footer").group()

    # Footer must already be the Explorer-style copyright footer.
    live_footer = one(FOOTER, live, "live footer").group()
    if "Feelcoin Network" not in live_footer or "In Feels We Trust" not in live_footer:
        raise RuntimeError("Unexpected live Pool footer: do not overwrite it blindly")
    if 'class="feel-social-btn"' in live_footer or "discord.com" in live_footer:
        raise RuntimeError("Legacy social buttons found inside footer")

    if CSS_START in live or CSS_END in live:
        if live.count(CSS_START) != 1 or live.count(CSS_END) != 1:
            raise RuntimeError("Partial/duplicate live CSS update")
        verify_header(live_header, "live", True)
        if one(STYLE, live, "existing CSS").group() != css:
            raise RuntimeError("Live header style differs from approved source")
        return live, False

    if "FEELCOIN_POOL_NAV_FOOTER_V1_END" not in live:
        raise RuntimeError("Pool nav baseline CSS not found")
    verify_header(live_header, "live", False)

    social_match = one(SOCIAL, live_header, "existing social buttons")
    nav_match = one(NAV, live_header, "existing desktop nav")
    if social_match.start() <= nav_match.end():
        raise RuntimeError("Social buttons unexpectedly inside desktop nav")
    # Move the existing social markup, preserving its links, labels, and icon.
    social_markup = social_match.group()
    removed = live_header[:social_match.start()] + live_header[social_match.end():]
    close_nav = removed.index("</nav>")
    changed_header = removed[:close_nav] + "\n" + social_markup + "\n" + removed[close_nav:]
    verify_header(changed_header, "updated", True)

    updated = live.replace(live_header, changed_header, 1)
    anchor = updated.index("/* FEELCOIN_POOL_NAV_FOOTER_V1_END */")
    close_style = updated.find("</style>", anchor)
    if close_style < 0:
        raise RuntimeError("Could not find matching Pool header CSS closing tag")
    updated = updated[:close_style] + css + "\n" + updated[close_style:]

    if updated.count(CSS_START) != 1:
        raise RuntimeError("Final CSS validation failed")
    if one(FOOTER, updated, "updated footer").group() != live_footer:
        raise RuntimeError("Footer accidentally changed")
    if updated.count('id="poolStatus"') != live.count('id="poolStatus"'):
        raise RuntimeError("Pool status changed unexpectedly")
    return updated, True


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", required=True, type=Path,
                   help="GitHub-approved Pool HTML from the fix branch")
    p.add_argument("--live", required=True, type=Path,
                   help="Current static Pool index.html")
    p.add_argument("--apply", action="store_true")
    args = p.parse_args()
    if not args.live.is_absolute() or args.live.name != "index.html":
        p.error("--live requires an absolute path to index.html")
    if args.live.is_symlink() or not args.live.is_file() or not args.source.is_file():
        p.error("Missing source or live HTML (or live path is a symlink)")
    old = args.live.read_text(encoding="utf-8")
    source = args.source.read_text(encoding="utf-8")
    new, changed = patch(old, source)
    if not changed:
        print("Already deployed: Downloads menu visible, larger nav, socials after GitHub, status right")
        return
    if not args.apply:
        print("Dry run OK: Downloads overlay, 14px nav, social buttons after GitHub, Pool Online last")
        print("No mining data, payouts, footer, or other website content will be changed")
        return

    previous = args.live.stat()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    backup = args.live.with_name(args.live.name + ".before-pool-header-polish-" + stamp)
    if backup.exists():
        raise RuntimeError("Backup path already exists")
    shutil.copy2(args.live, backup)
    fd, tmp = tempfile.mkstemp(dir=args.live.parent, prefix=".pool-nav-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(new)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(tmp, stat.S_IMODE(previous.st_mode))
        os.chown(tmp, previous.st_uid, previous.st_gid)
        os.replace(tmp, args.live)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    print("SUCCESS: Pool header fixes deployed")
    print("Backup:", backup)


if __name__ == "__main__":
    main()
