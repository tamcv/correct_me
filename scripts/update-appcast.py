#!/usr/bin/env python3
"""Update dist/appcast.xml with a new release entry.

Usage:
    python3 scripts/update-appcast.py \
        --version 0.3.6 \
        --tag v0.3.6 \
        --bundle-version 36 \
        --dmg-url https://github.com/... \
        --length 12345678 \
        --signature abc123== \
        --pub-date "Mon, 20 Apr 2026 12:00:00 +0000"
"""
import argparse
import re
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--version", required=True)
parser.add_argument("--tag", required=True)
parser.add_argument("--bundle-version", required=True)
parser.add_argument("--dmg-url", required=True)
parser.add_argument("--length", required=True)
parser.add_argument("--signature", required=True)
parser.add_argument("--pub-date", required=True)
parser.add_argument("--appcast", default="dist/appcast.xml")
args = parser.parse_args()

new_item = f"""
    <item>
      <title>CorrectMe {args.version}</title>
      <sparkle:version>{args.bundle_version}</sparkle:version>
      <sparkle:shortVersionString>{args.version}</sparkle:shortVersionString>
      <pubDate>{args.pub_date}</pubDate>
      <enclosure
        url="{args.dmg_url}"
        sparkle:version="{args.bundle_version}"
        sparkle:shortVersionString="{args.version}"
        length="{args.length}"
        type="application/octet-stream"
        sparkle:edSignature="{args.signature}"
      />
    </item>
"""

with open(args.appcast, "r") as f:
    content = f.read()

if args.tag in content:
    print(f"Tag {args.tag} already in appcast.xml, skipping.")
    sys.exit(0)

content = content.replace("  </channel>", new_item + "  </channel>")

with open(args.appcast, "w") as f:
    f.write(content)

print(f"appcast.xml updated with {args.version}")
