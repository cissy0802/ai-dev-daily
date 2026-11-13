#!/bin/bash
# BigCat Learning Hub — publish script, ai-dev-daily variant (seen.tsv ledger, Chinese-only).
# Auto-derives N, commit message, and URL from filesystem state.
# Usage: ./publish.sh   (no args)
#
# Handles two file-layout modes:
#   - LEGACY embedded: single  *-{day,week,book,issue}{N}.html  per topic
#   - SPLIT bilingual: pair    *-{day,week,...}{N}.html  +  *-{...}{N}.en.html
#
# Guards (filesystem is source of truth, not TOPICS.md):
#   - new content file exists matching the pattern above
#   - each new file is not a tiny error stub (>2KB)
#   - index.html references the new Chinese file (index.en.html refs the .en one if present)
#   - no DUPLICATE N (treats day1 / day01 / day9 / day09 as same N=9)
#   - no hardcoded shared scripts (comments/search/index-button/i18n-tts)
#   - <div> balance + data-zh/data-en attribute integrity
#   - pushes to main via HEAD:main (bypasses claude/* harness branches)
#   - also pushes current branch to origin (keeps claude/* harness branches in sync with stop-hook)
#   - retries push up to 3 times on transient failures

set -e

# Collect all new (untracked + modified) HTML files matching the topic pattern.
# Excludes index.html — that's expected to be modified, not "the new content".
NEW_FILES=$(git status --porcelain | grep -oE '\S+-day[0-9]+\.html$' | sort -u)
[ -z "$NEW_FILES" ] && { echo "ERROR: no new *-{day,week,book,issue}{N}[.en].html in working tree"; exit 1; }

# Primary (Chinese) file = the non-.en one if any, else the .en one
PRIMARY=$(echo "$NEW_FILES" | grep -v '\.en\.html$' | head -1)
[ -z "$PRIMARY" ] && PRIMARY=$(echo "$NEW_FILES" | head -1)

PADDED_N=$(echo "$PRIMARY" | grep -oE '[0-9]+' | tail -1)
N=$((10#$PADDED_N))
KIND=day

TITLE=$(grep -oE '<title>[^<]+' "$PRIMARY" | head -1 | sed 's|<title>||')
[ -z "$TITLE" ] && TITLE="$PRIMARY"
MSG="${MSG:-Add #$N: $TITLE}"

# ---------- SOURCES guard ----------
# SOURCES.md is BigCat's. A run that edits it is widening its own remit.
if ! git diff --quiet HEAD -- SOURCES.md 2>/dev/null; then
  echo "ERROR: SOURCES.md was modified by this run. It is read-only for the engine."
  exit 1
fi
[ -n "$(git status --porcelain -- '*.en.html')" ] && { echo "ERROR: this site is Chinese-only; remove the .en.html file."; exit 1; }

# ---------- seen.tsv ledger (dedupe across days) ----------
# Every source link on the new page must be a row added to seen.tsv by this
# run with status=pub, and none of those URLs may already be in the ledger.
# This is what stops a post from resurfacing three days running.
python3 - "$PRIMARY" <<'PY' || exit 1
import sys, re, subprocess, csv, io
page = sys.argv[1]
h = open(page, encoding="utf-8").read()
def rows(text):
    r = list(csv.reader(io.StringIO(text), delimiter="\t"))
    return r[1:] if r and r[0][:3] == ["date", "status", "url"] else None
try:
    old = rows(subprocess.run(["git", "show", "HEAD:seen.tsv"], capture_output=True, text=True, check=True).stdout) or []
except subprocess.CalledProcessError:
    old = []
new_all = rows(open("seen.tsv", encoding="utf-8").read())
if new_all is None:
    sys.exit("ERROR: seen.tsv header must be: date<TAB>status<TAB>url<TAB>title")
if new_all[:len(old)] != old:
    sys.exit("ERROR: seen.tsv: existing rows were edited or reordered — append only.")
added = new_all[len(old):]
bad = [r for r in added if len(r) != 4 or r[1] not in ("pub", "skip") or not r[2].startswith("http")]
if bad:
    sys.exit(f"ERROR: seen.tsv: malformed new rows (need date, pub|skip, url, title): {bad[:3]}")
old_urls = {r[2] for r in old if len(r) > 2}
dup = [r[2] for r in added if r[2] in old_urls]
if dup:
    sys.exit(f"ERROR: already covered on an earlier day (seen.tsv): {dup}")
pub = {r[2] for r in added if r[1] == "pub"}
body = re.sub(r"<(script|style).*?</\1>", "", h, flags=re.S)
srcs = re.findall(r'<a class="src" href="([^"]+)"', body)
if not srcs:
    sys.exit("ERROR: page has no <a class=\"src\"> source links.")
missing = [u for u in srcs if u not in pub]
if missing:
    sys.exit(f"ERROR: source links not logged as new pub rows in seen.tsv: {missing}")
orphan = sorted(pub - set(srcs))
if orphan:
    sys.exit(f"ERROR: seen.tsv pub rows with no link on the page (mark them skip): {orphan}")
for i, art in enumerate(re.findall(r'<article class="item">(.*?)</article>', body, re.S), 1):
    if 'class="src"' not in art:
        sys.exit(f"ERROR: lead item #{i} has no source link.")
if len(re.findall(r'<article class="item">', body)) > 3:
    sys.exit("ERROR: more than 3 lead items — move the rest to 也值得知道.")
if len(re.findall(r"<li>", body.split('class="brief"', 1)[1])) > 8 if 'class="brief"' in body else False:
    sys.exit("ERROR: more than 8 brief items.")
if "{{" in body:
    sys.exit("ERROR: unfilled {{…}} placeholder left from TEMPLATE.")
print(f"seen.tsv OK: {len(pub)} pub, {len(added) - len(pub)} skip")
PY

# ---------- Per-file validations ----------
for F in $NEW_FILES; do
  [ ! -f "$F" ] && continue

  # Size guard
  [ $(wc -c < "$F") -lt 2000 ] && { echo "ERROR: $F only $(wc -c < $F) bytes, likely incomplete"; exit 1; }

  # Length ceiling (optional, opt-in per repo via .maxchars file).
  # Counts CJK chars only (strips <style>/<script>/tags). Defends against the
  # self-imitation ratchet where each issue mimics the last and grows ~20%/gen.
  # Only applies to the Chinese file (.en has ~0 CJK and passes trivially).
  if [ -f .maxchars ] && ! echo "$F" | grep -q '\.en\.html$'; then
    LIMIT=$(tr -dc '0-9' < .maxchars)
    CJK=$(python3 -c 'import sys,re;h=sys.stdin.read();h=re.sub(r"<style.*?</style>","",h,flags=re.S);h=re.sub(r"<script.*?</script>","",h,flags=re.S);h=re.sub(r"<[^>]+>","",h);print(len(re.findall(r"[一-鿿]",h)))' < "$F")
    if [ -n "$LIMIT" ] && [ "$CJK" -gt "$LIMIT" ]; then
      echo "ERROR: $F has $CJK CJK chars > limit $LIMIT (.maxchars)."
      echo "       Trim the longest paragraphs (don't rewrite wholesale) and re-run."
      exit 1
    fi
  fi

  # Reference check: Chinese file must be in index.html, .en file in index.en.html (if exists)
  if echo "$F" | grep -q '\.en\.html$'; then
    if [ -f index.en.html ]; then
      grep -q "$F" index.en.html || { echo "ERROR: index.en.html does not reference $F"; exit 1; }
    fi
  else
    grep -q "$F" index.html || { echo "ERROR: index.html does not reference $F"; exit 1; }
  fi

  # Forbidden hardcoded scripts (auto-injected by GitHub Action)
  for s in comments.js search.js index-button.js i18n-tts.js; do
    grep -q "$s" "$F" && { echo "ERROR: $F hardcodes $s (auto-injected, will duplicate)"; exit 1; }
  done
  grep -q "← Hub" "$F" && echo "WARN: $F hardcodes ← Hub button (will be deduped, consider removing)"

  # Markdown leaking into HTML: **bold** renders as literal asterisks.
  # Issue #1 shipped 11 of them per page before this guard existed.
  MD_BOLD=$(python3 -c 'import sys,re;h=sys.stdin.read();h=re.sub(r"<(script|style).*?</\1>","",h,flags=re.S);print(len(re.findall(r"\*\*[^*\n]+\*\*",h)))' < "$F")
  if [ "$MD_BOLD" -gt 0 ]; then
    echo "ERROR: $F has $MD_BOLD Markdown **bold** run(s) — HTML shows the asterisks."
    echo "       Use <strong>…</strong> instead."
    exit 1
  fi

  # <div> balance
  OPENS=$(grep -oE '<div[ >]' "$F" | wc -l | tr -d ' ')
  CLOSES=$(grep -oE '</div>' "$F" | wc -l | tr -d ' ')
  if [ "$OPENS" != "$CLOSES" ]; then
    echo "ERROR: $F has unbalanced <div>: $OPENS opens vs $CLOSES closes (diff $((OPENS-CLOSES)))"
    exit 1
  fi

  # data-zh/data-en attribute integrity (catch ASCII " inside attribute value)
  BAD_ATTR=$(grep -cE 'data-(zh|en)="[^"]*"[^ />]' "$F" || true)
  if [ "$BAD_ATTR" -gt 0 ]; then
    echo "ERROR: $F has $BAD_ATTR data-zh/data-en attribute(s) with unescaped ASCII \" inside value."
    echo "       Use 「」 / 『』 or HTML entity &quot;"
    exit 1
  fi
done

# ---------- Duplicate N check (across same KIND, both lang variants) ----------
DUP=""
for existing in *-${KIND}*.html; do
  [ ! -f "$existing" ] && continue
  # Skip if this file is itself one of the new files
  echo "$NEW_FILES" | grep -q "^${existing}$" && continue
  EXISTING_PADDED=$(echo "$existing" | grep -oE '[0-9]+' | tail -1)
  EXISTING_N=$((10#$EXISTING_PADDED))
  # Only compare same lang variant: split-mode produces both x.html and x.en.html
  IS_EN_EXISTING=$(echo "$existing" | grep -c '\.en\.html$' || true)
  IS_EN_PRIMARY=$(echo "$PRIMARY" | grep -c '\.en\.html$' || true)
  if [ "$EXISTING_N" = "$N" ] && [ "$IS_EN_EXISTING" = "$IS_EN_PRIMARY" ]; then
    DUP="$DUP $existing"
  fi
done
if [ -n "$DUP" ]; then
  echo "ERROR: ${KIND} #$N already exists:$DUP"
  echo "       Check filesystem before regenerating."
  exit 1
fi

# ---------- Commit + push ----------
git config user.email "chengchen0802@gmail.com"
git config user.name "BigCat"
git add -A
git diff --cached --quiet && { echo "Nothing to commit."; exit 0; }
git commit -m "$MSG"

for i in 1 2 3; do
  if git push origin HEAD:main 2>/dev/null; then
    echo "✓ Pushed: $MSG"
    REPO=$(basename "$(pwd)")
    echo "→ https://cissy0802.github.io/$REPO/$PRIMARY"
    EN_FILE=$(echo "$NEW_FILES" | grep '\.en\.html$' | head -1)
    [ -n "$EN_FILE" ] && echo "→ https://cissy0802.github.io/$REPO/$EN_FILE"
    # Also push current branch (keeps claude/* harness branches in sync with stop-hook).
    CURBRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURBRANCH" != "main" ] && [ "$CURBRANCH" != "HEAD" ]; then
      git push -u origin HEAD >/dev/null 2>&1 && echo "✓ Also synced branch: $CURBRANCH"
    fi
    exit 0
  fi
  echo "Push attempt $i failed, fetching and rebasing..."
  git fetch origin main
  git rebase origin/main || { git rebase --abort; echo "Rebase failed"; }
  [ $i -lt 3 ] && sleep 2
done
echo "ERROR: push failed after 3 attempts"
exit 1
