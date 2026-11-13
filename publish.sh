#!/bin/bash
# AI-native 转型笔记 — publish. The engine edits data/ only; this script
# validates the data against HEAD, rebuilds every page with build.py, and pushes.
#
# Gates (each one exists because a run could otherwise quietly degrade the site):
#   - SOURCES.md untouched (BigCat's; widening sources is her call)
#   - seen.tsv append-only; new pub rows == urls of entries added this run;
#     no added url seen on an earlier day
#   - no entry deleted; ids stable
#   - every added/modified entry has a changelog row dated today;
#     modified entries carry updated + update_note
#   - build.py validation (schema, inline-HTML whitelist, #e- links resolve)
#   - CJK size ceiling per page (.maxchars)
#   - pushes HEAD:main with retries; message "Add #<entries>: ..." so the hub
#     card's date (generate_hub.py fast path) moves on every publish
set -e
cd "$(dirname "$0")"

if ! git diff --quiet HEAD -- SOURCES.md 2>/dev/null; then
  echo "ERROR: SOURCES.md was modified by this run. It is read-only for the engine."; exit 1
fi

python3 - <<'PY' || exit 1
import csv, io, json, subprocess, sys, datetime, zoneinfo
today = datetime.datetime.now(zoneinfo.ZoneInfo("America/Los_Angeles")).date().isoformat()
def head(path):
    r = subprocess.run(["git", "show", f"HEAD:{path}"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""
def jl(text): return [json.loads(l) for l in text.splitlines() if l.strip()]
def tsv(text):
    r = list(csv.reader(io.StringIO(text), delimiter="\t"))
    return r[1:] if r and r[0][:3] == ["date", "status", "url"] else None

old_e = {e["id"]: e for e in jl(head("data/entries.jsonl"))}
new_e = {e["id"]: e for e in jl(open("data/entries.jsonl", encoding="utf-8").read())}
gone = sorted(set(old_e) - set(new_e))
if gone: sys.exit(f"ERROR: entries deleted: {gone}. Entries are never removed; mark them updated instead.")
added = [i for i in new_e if i not in old_e]
changed = [i for i in new_e if i in old_e and new_e[i] != old_e[i]]
if not added and not changed:
    sys.exit("ERROR: no entry added or modified — nothing to publish. (Quiet day: don't run publish.sh.)")
for i in changed:
    if new_e[i].get("url") != old_e[i].get("url"):
        sys.exit(f"ERROR: entry {i}: url changed. Add a new entry for a new source.")
    if new_e[i].get("updated") != today or not new_e[i].get("update_note"):
        sys.exit(f"ERROR: entry {i} modified but updated != {today} or update_note empty.")
for i in added:
    if new_e[i].get("added") != today:
        sys.exit(f"ERROR: new entry {i}: added must be {today}.")

old_log = jl(head("data/changelog.jsonl"))
new_log = jl(open("data/changelog.jsonl", encoding="utf-8").read())
if new_log[:len(old_log)] != old_log: sys.exit("ERROR: changelog.jsonl is append-only.")
logged = {(r["id"], r["action"]) for r in new_log[len(old_log):] if r.get("date") == today}
miss = [f"{i}:add" for i in added if (i, "add") not in logged] + [f"{i}:update" for i in changed if (i, "update") not in logged]
if miss: sys.exit(f"ERROR: changelog rows missing for {miss} (date {today}).")

old_rows = tsv(head("seen.tsv")) or []
new_rows = tsv(open("seen.tsv", encoding="utf-8").read())
if new_rows is None: sys.exit("ERROR: seen.tsv header must be date<TAB>status<TAB>url<TAB>title")
if new_rows[:len(old_rows)] != old_rows: sys.exit("ERROR: seen.tsv is append-only.")
fresh = new_rows[len(old_rows):]
bad = [r for r in fresh if len(r) != 4 or r[1] not in ("pub", "skip") or not r[2].startswith("http")]
if bad: sys.exit(f"ERROR: malformed seen.tsv rows: {bad[:3]}")
seen_before = {r[2] for r in old_rows}
dup = [r[2] for r in fresh if r[2] in seen_before]
if dup: sys.exit(f"ERROR: urls already in seen.tsv from an earlier day: {dup}")
pub = {r[2] for r in fresh if r[1] == "pub"}
want = {new_e[i]["url"] for i in added}
if pub != want:
    sys.exit(f"ERROR: new pub rows must equal urls of entries added this run.\n  pub-not-entry: {sorted(pub-want)}\n  entry-not-pub: {sorted(want-pub)}")
print(f"data OK: +{len(added)} new, {len(changed)} revised, {len(fresh)-len(pub)} skipped")
open("/tmp/.aidev_msg", "w").write(json.dumps({"added": added, "changed": changed, "n": len(new_e),
    "head": (new_e[added[0]] if added else new_e[changed[0]])["headline"]}))
PY

python3 build.py

if [ -f .maxchars ]; then
  LIMIT=$(tr -dc '0-9' < .maxchars)
  for F in *-topic*.html; do
    CJK=$(python3 -c 'import sys,re;h=sys.stdin.read();h=re.sub(r"<(style|script).*?</\1>","",h,flags=re.S);h=re.sub(r"<[^>]+>","",h);print(len(re.findall(r"[一-鿿]",h)))' < "$F")
    if [ "$CJK" -gt "$LIMIT" ]; then
      echo "WARN: $F has $CJK CJK chars (> $LIMIT). Tighten older entries or tell BigCat the category should split."
    fi
  done
fi

MSG=$(python3 -c 'import json,re;m=json.load(open("/tmp/.aidev_msg"));h=re.sub(r"<[^>]+>","",m["head"]);print("Add #%d: +%d new, %d revised — %s" % (m["n"], len(m["added"]), len(m["changed"]), h))')
git config user.email "chengchen0802@gmail.com"
git config user.name "BigCat"
git add -A
git diff --cached --quiet && { echo "Nothing to commit."; exit 0; }
git commit -q -m "$MSG"
for i in 1 2 3; do
  if git push -q origin HEAD:main 2>/dev/null; then
    echo "✓ Pushed: $MSG"
    echo "→ https://hub.cissychen.com/ai-dev-daily/"
    CUR=$(git rev-parse --abbrev-ref HEAD)
    [ "$CUR" != "main" ] && [ "$CUR" != "HEAD" ] && git push -q -u origin HEAD >/dev/null 2>&1 || true
    exit 0
  fi
  echo "Push attempt $i failed, rebasing..."
  git fetch -q origin main && git rebase -q origin/main || { git rebase --abort; echo "Rebase failed"; }
  sleep 2
done
echo "ERROR: push failed after 3 attempts"; exit 1
