#!/usr/bin/env python3
"""Publish only Feelcoin Pool navigation polish to its live static homepage.

Reads the approved CSS from web/chain-dashboard/index.html at GitHub.
Dry-run by default. With --apply, creates a timestamped backup and atomically
updates only the explicitly marked CSS section (not Pool JS or mining logic).
"""
import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import re
import shutil
import stat
import tempfile

START = "/* FEELCOIN_POOL_NAV_REFINEMENT_V3_START */"
END = "/* FEELCOIN_POOL_NAV_REFINEMENT_V3_END */"
BLOCK = re.compile(re.escape(START) + r".*?" + re.escape(END), re.S)


def once(pattern, value, name):
    matches = list(pattern.finditer(value))
    if len(matches) != 1:
        raise RuntimeError(f"{name}: expected one CSS block; found {len(matches)}")
    return matches[0]


def patch(live, approved):
    css = once(BLOCK, approved, "Approved GitHub source").group()
    for name, html in (("Source", approved), ("Live", live)):
        for phrase in (
            '<header class="topbar">',
            'class="fc-pool-social-right"',
            '<div class="status">',
            '<summary>Downloads ',
            'id="poolStatus"',
        ):
            if phrase not in html:
                raise RuntimeError(f"{name}: expected Pool header markup missing: {phrase}")
        if html.count('<summary>Downloads ') != 2:
            raise RuntimeError(f"{name}: expected desktop and mobile Downloads menus")
        if html.count('class="fc-pool-social-right"') != 1:
            raise RuntimeError(f"{name}: expected one header social group")
    for required in (
        'font-size:15px !important;',
        'font-weight:700 !important;',
        'margin-left:0 !important;',
        'z-index:5000 !important;',
    ):
        if required not in css:
            raise RuntimeError(f"Approved CSS is missing {required}")

    if START in live or END in live:
        if live.count(START) != 1 or live.count(END) != 1:
            raise RuntimeError("Partial or repeated Pool nav styling; refusing")
        m = once(BLOCK, live, "Live Pool CSS")
        result = live[:m.start()] + css + live[m.end():]
    else:
        head_end = live.find("</head>")
        style_end = live.rfind("</style>", 0, head_end)
        if head_end < 0 or style_end < 0:
            raise RuntimeError("Could not find last head stylesheet")
        result = live[:style_end] + css + "\n" + live[style_end:]

    if result.count(START) != 1 or result.count(END) != 1:
        raise RuntimeError("Post-patch stylesheet validation failed")
    return result, result != live


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--live", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    path = args.live
    if not path.is_absolute() or path.name != "index.html":
        parser.error("--live must be an absolute path ending in index.html")
    if path.is_symlink() or not path.is_file() or not args.source.is_file():
        parser.error("Source/live file missing or live file is a symlink")

    before = path.read_text(encoding="utf-8")
    source = args.source.read_text(encoding="utf-8")
    result, changed = patch(before, source)
    if not changed:
        print("Already installed: bold 15px buttons, grouped status, fixed popup")
        return
    if not args.apply:
        print("Dry run OK: bold 15px navigation, Pool Online beside social buttons")
        print("Downloads dropdown raised above hero; all other content untouched")
        return

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    backup = path.with_name(path.name + ".before-pool-nav-refinement-" + stamp)
    if backup.exists():
        raise RuntimeError("Backup exists: " + str(backup))
    metadata = path.stat()
    shutil.copy2(path, backup)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".feelcoin-pool-nav-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(result)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp, stat.S_IMODE(metadata.st_mode))
        os.chown(tmp, metadata.st_uid, metadata.st_gid)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    print("SUCCESS: Pool header refinement installed")
    print("Backup:", backup)


if __name__ == "__main__":
    main()
