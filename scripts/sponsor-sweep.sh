#!/usr/bin/env sh
# Wire sponsorship into a repo: the README section, the gloam footer link, or both.
# One PR per repo. Idempotent — a repo that already asks is skipped.
#
# The Sponsor button comes from this repo's .github/FUNDING.yml and already covers
# every repository. This is emphasis, not mechanism: the button sits in the repo
# sidebar, while a README is what someone reads in the minute after the project
# turned out to be useful, and a site footer is where a visitor who never opens
# GitHub can see it at all.
#
# Usage: sponsor-sweep.sh [--dry-run] [--readme-only|--footer-only] <repos-root> <repo>...
set -eu

DRY=0; DO_README=1; DO_FOOTER=1
while :; do
  case "${1:-}" in
    --dry-run)     DRY=1; shift ;;
    --readme-only) DO_FOOTER=0; shift ;;
    --footer-only) DO_README=0; shift ;;
    *) break ;;
  esac
done
ROOT="$1"; shift
BRANCH="feat/sponsor"
URL="https://github.com/sponsors/richardwooding"

for r in "$@"; do
  cd "$ROOT/$r" 2>/dev/null || { echo "MISSING  $r"; continue; }
  # Repos cloned on another machine have no identity, and git then refuses to
  # commit. Set it only when absent, so a repo with its own stays untouched.
  git config user.name  >/dev/null 2>&1 || git config user.name  "Richard Wooding"
  git config user.email >/dev/null 2>&1 || git config user.email "richard.wooding@gmail.com"
  git switch -q main 2>/dev/null && git pull -q --ff-only 2>/dev/null || true

  # Python does the editing: both insertions need to reason about context (the
  # last License heading, a missing trailing newline, the single gl-fnav block),
  # which is where a sed one-liner would quietly get it wrong.
  RESULT=$(DRY="$DRY" DO_README="$DO_README" DO_FOOTER="$DO_FOOTER" URL="$URL" python3 - <<'PY'
import os, glob, re, sys

dry = os.environ["DRY"] == "1"
url = os.environ["URL"]
did = []

SECTION = f"""## Sponsor

If this saves you time, you can [sponsor its maintenance]({url}).
Sponsorship pays for the unglamorous half — triage, dependency bumps, release plumbing — and is
never a condition of getting help here.
"""

HEART = ('<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
         'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
         '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8z"/></svg>')

def anchor(ind):
    """The link, indented to sit with its siblings rather than with the closing tag."""
    return (f'{ind}<a class="gl-sponsor" href="{url}">\n'
            f'{ind}  {HEART}\n'
            f'{ind}  Sponsor\n'
            f'{ind}</a>\n')

# --- README section -------------------------------------------------------
if os.environ["DO_README"] == "1" and os.path.exists("README.md"):
    s = open("README.md").read()
    if re.search(r"(?im)^##\s+sponsor\b", s) or "sponsors/richardwooding" in s:
        did.append("readme: already asks")
    else:
        heads = [m.start() for m in re.finditer(r"(?im)^##\s+licen[cs]e\s*$", s)]
        if heads:
            at = heads[-1]
            s = s[:at] + SECTION + "\n" + s[at:]
            did.append("readme: before ## License")
        elif re.search(r"(?m)^## ", s):
            if not s.endswith("\n"):
                s += "\n"
            if s.splitlines()[-1].strip():
                s += "\n"
            s += SECTION
            did.append("readme: appended (no License heading)")
        else:
            did.append("readme: SKIPPED (no H2 at all)")
            s = None
        if s is not None and not dry:
            open("README.md", "w").write(s)

# --- gloam footer link ----------------------------------------------------
if os.environ["DO_FOOTER"] == "1":
    pages = [p for p in ("docs/index.html", "site/index.html", "web/src/index.html")
             if os.path.exists(p) and os.path.exists(os.path.join(os.path.dirname(p), "gloam.css"))]
    for p in pages:
        h = open(p).read()
        if "gl-sponsor" in h or "sponsors/richardwooding" in h:
            did.append(f"{p}: already asks"); continue
        m = re.search(r'(<nav class="gl-fnav">)(.*?)(\n[ \t]*)(</nav>)', h, re.S)
        if not m:
            did.append(f"{p}: SKIPPED (no gl-fnav)"); continue
        inner, closing = m.group(2), m.group(3) + m.group(4)
        # Take the indent from the last sibling link, not from the closing tag —
        # otherwise the anchor lands two columns short of every other entry.
        sibs = [l for l in inner.splitlines() if l.lstrip().startswith("<a ")]
        ind = sibs[-1][:len(sibs[-1]) - len(sibs[-1].lstrip())] if sibs else "      "
        h = h[:m.end(2)] + "\n" + anchor(ind).rstrip("\n") + closing + h[m.end(4):]
        did.append(f"{p}: footer link")
        if not dry:
            open(p, "w").write(h)

print("; ".join(did) if did else "nothing to do")
PY
)
  echo "$r: $RESULT"
  case "$RESULT" in *"already asks"*|*"nothing to do"*) [ -z "$(git status --porcelain)" ] && continue ;; esac
  [ "$DRY" = 1 ] && { git checkout -q . 2>/dev/null || true; continue; }
  [ -z "$(git status --porcelain)" ] && continue

  git switch -q "$BRANCH" 2>/dev/null || git switch -qc "$BRANCH"
  git add -A
  git commit -q -m "feat: ask for sponsorship, in the two places people read

The .github default FUNDING.yml already puts a Sponsor button on this repo,
but the button lives in the sidebar where nobody looks. The README section
sits next to the licence, where someone who has just found this useful is
already reading; the site footer reaches the visitors who never open GitHub.

Wording is identical across every repo on purpose: one place to change if the
ask changes, and no per-repo pleading. The footer link is styled by gloam's
gl-sponsor class, which arrived with the last asset sync."
  git push -q -u origin "$BRANCH"
  gh pr create --title "feat: ask for sponsorship, in the two places people read" --body "$(printf 'The [\`richardwooding/.github\`](https://github.com/richardwooding/.github) default \`FUNDING.yml\` already gives this repo a Sponsor button, so this is emphasis rather than mechanism — the button sits in the sidebar, while the README is what someone reads in the minute after the project turned out to be useful, and the site footer reaches visitors who never open GitHub.\n\nWording is byte-identical across the sweep so there is one place to edit if the ask changes. Deliberately no badge: about thirty repos have no badge block at all, and forcing one in for this would read worse than the section does.\n\nThe footer link uses gloam'"'"'s `.gl-sponsor` class, which landed in the last `chore(site): sync gloam design assets`. gloam ships the style; the anchor is the site'"'"'s own, so an asset sync can never change what a page asks for.\n\nSwept with `scripts/sponsor-sweep.sh` in [richardwooding/.github](https://github.com/richardwooding/.github).')"
  sleep 4   # GitHub secondary rate limits bite on bulk content creation
done
