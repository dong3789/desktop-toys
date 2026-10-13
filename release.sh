#!/bin/bash
# Usage: ./release.sh 1.0.1 "릴리스 노트"   — builds, zips, commits, tags, publishes a GitHub release
set -e; cd "$(dirname "$0")"
V="$1"; NOTES="${2:-버그 수정 및 개선}"
[ -z "$V" ] && { echo "usage: ./release.sh <version> [notes]"; exit 1; }
REPO=dong3789/desktop-toys
export GH_TOKEN=$(gh auth token --user dong3789)          # publish as the personal account without switching gh
echo "$V" > VERSION
STAGE=$(mktemp -d); APP="$STAGE/DesktopToys.app" ./build.sh   # build into staging; installed copies update via the in-app updater
S=$(mktemp -d)/DesktopToys; mkdir -p "$S"
ditto "$STAGE/DesktopToys.app" "$S/DesktopToys.app"; xattr -cr "$S/DesktopToys.app"
cp dist-assets/설치방법.txt "$S/"
rm -f DesktopToys.zip; (cd "$(dirname "$S")" && ditto -c -k --keepParent DesktopToys "$OLDPWD/DesktopToys.zip")
cp DesktopToys.zip ~/Desktop/DesktopToys.zip
git add -A && git commit -qm "v$V" || true
git tag -f "v$V"
git -c credential.helper= -c credential.helper='!gh auth git-credential' push -q origin HEAD:main
git -c credential.helper= -c credential.helper='!gh auth git-credential' push -qf origin "v$V"
gh release create "v$V" DesktopToys.zip --repo $REPO --title "DesktopToys $V" --notes "$NOTES"
echo "released v$V → https://github.com/$REPO/releases/tag/v$V"
