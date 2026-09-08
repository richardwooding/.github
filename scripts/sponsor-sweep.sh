#!/usr/bin/env sh
# Add the standard "## Sponsor" section to one or more repos, one PR each.
#
# The Sponsor button comes from this repo's .github/FUNDING.yml and already covers
# every repository. This script is emphasis, not mechanism: the button sits in the
# repo sidebar where nobody looks, while a README is what someone reads in the
# minute after the project turned out to be useful.
#
# Idempotent and re-runnable: a repo that already mentions sponsorship is skipped.
#
# Usage: sponsor-sweep.sh <repos-root> <repo> [<repo> ...]
#        sponsor-sweep.sh --dry-run <repos-root> <repo> [<repo> ...]
set -eu

DRY=0
[ "${1:-}" = "--dry-run" ] && { DRY=1; shift; }
ROOT="$1"; shift
BRANCH="docs/sponsor-section"

# The canonical block, without surrounding blank lines. One place to edit if the
# ask ever changes.
block() {
  printf '## Sponsor\n\n'
  printf 'If this saves you time, you can [sponsor its maintenance](https://github.com/sponsors/richardwooding).\n'
  printf 'Sponsorship pays for the unglamorous half — triage, dependency bumps, release plumbing — and is\n'
  printf 'never a condition of getting help here.\n'
}

for r in "$@"; do
  cd "$ROOT/$r" || { echo "MISSING  $r"; continue; }

  if grep -qiE '^##[[:space:]]+Sponsor|sponsors/richardwooding' README.md 2>/dev/null; then
    echo "SKIP     $r (already asks)"
    continue
  fi

  # Insert before the LAST "## License" heading — a couple of READMEs mention
  # licensing earlier in prose, and the tail one is the real section.
  ln=$(grep -niE '^##[[:space:]]+Licen[cs]e' README.md | tail -1 | cut -d: -f1 || true)
  mode=insert
  if [ -z "$ln" ]; then
    # No licence heading (powerdown, txtr): append at the very end. NOT "insert
    # before the last line + 1" — powerdown's README has no trailing newline, so
    # a line-counted insert lands before its final line, which is a closing code
    # fence. The section would end up inside the fenced block.
    if grep -qE '^## ' README.md; then
      mode=append
    else
      echo "REPORT   $r (no H2 at all — handle by hand)"
      continue
    fi
  fi

  if [ "$DRY" = 1 ]; then
    if [ "$mode" = append ]; then echo "WOULD    $r → append at EOF (no License heading)"
    else echo "WOULD    $r → insert before line $ln (## License)"; fi
    continue
  fi

  git switch -q main && git pull -q --ff-only
  git switch -qc "$BRANCH"
  if [ "$mode" = append ]; then
    # A file not ending in a newline would otherwise glue the heading onto its
    # last line; $( ) strips a trailing newline, so a non-empty result means one
    # is missing.
    [ -n "$(tail -c1 README.md)" ] && printf '\n' >> README.md
    # …and only add a separating blank line if the file does not already end on
    # one (txtr does), or the section arrives with a double gap above it.
    [ -n "$(tail -n1 README.md)" ] && printf '\n' >> README.md
    block >> README.md
  else
    { block; printf '\n'; } > /tmp/sponsor-block.$$
    awk -v n="$ln" -v f=/tmp/sponsor-block.$$ 'NR==n{ while ((getline l < f) > 0) print l } { print }' \
      README.md > README.md.new && mv README.md.new README.md
    rm -f /tmp/sponsor-block.$$
  fi

  git commit -q -am "docs(readme): add a Sponsor section

The .github default FUNDING.yml already puts a Sponsor button on this repo,
but the button lives in the sidebar where nobody looks. A line next to the
licence is where someone who has just found the project useful is reading.

Wording is identical across every repo on purpose: one place to change if the
ask ever changes, and no per-repo pleading."
  git push -q -u origin "$BRANCH"
  gh pr create --title "docs(readme): add a Sponsor section" --body "Adds the standard Sponsor section immediately before \`## License\`.

The \`richardwooding/.github\` default \`FUNDING.yml\` already gives this repo a Sponsor button, so this is emphasis rather than mechanism — the button sits in the sidebar, while the README is what someone reads in the minute after the project turned out to be useful.

Wording is byte-identical across the sweep so there is one place to edit if the ask changes. Deliberately no badge: about thirty repos have no badge block at all, and forcing one in for this would look worse than the section reads.

Swept with \`scripts/sponsor-sweep.sh\` in [richardwooding/.github](https://github.com/richardwooding/.github)."
  echo "OPENED   $r"
  sleep 5   # GitHub's secondary rate limits bite on bulk content creation
done
