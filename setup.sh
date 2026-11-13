#!/usr/bin/env bash
# ai-dev-daily — preflight. The engine runs this itself every run (CLAUDE.md §0).
#
# This routine shares the "blog" environment with the deepread sites; that
# environment's allowlist was built for *their* sources. Whether it reaches
# anthropic.com / openai.com / claude.com is exactly what this settles, loudly.
#
# Probes are the hosts this repo actually reads (never example.com: under
# Custom network access a neutral host is blocked by design and would turn a
# correct environment into a false BLOCKED). Each source group is reported on
# its own so a partial block is visible on the page, not silently skipped.
#
# Never exits non-zero — a failed preflight is a fact for the engine to act on.

set -u
PREFLIGHT=".preflight"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'

probe() {
  curl -sS -o /dev/null --max-time 10 -A "$UA" -w '%{http_code}' "$1" 2>/dev/null
}

# group|url  — a group is OK if any of its URLs answers 2xx/3xx
PROBES="
anthropic|https://www.anthropic.com/news
anthropic|https://www.anthropic.com/engineering
anthropic|https://claude.com/blog
anthropic|https://platform.claude.com/docs/en/release-notes/overview
openai|https://openai.com/news/rss.xml
openai|https://developers.openai.com/changelog
google|https://developers.googleblog.com/
google|https://deepmind.google/discover/blog/
github|https://api.github.com/repos/openai/codex/releases?per_page=1
github|https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md
ecosystem|https://github.blog/changelog/feed/
ecosystem|https://cursor.com/changelog
discovery|https://simonwillison.net/atom/everything/
discovery|https://hn.algolia.com/api/v1/search?tags=front_page
"

RESULTS=""
while IFS='|' read -r g u; do
  [ -z "$g" ] && continue
  code=$(probe "$u"); [ -z "$code" ] && code="000"
  RESULTS="${RESULTS}  [$g] $u -> $code"$'\n'
  case "$code" in 2*|3*) eval "OK_$g=1" ;; esac
done <<< "$PROBES"

NONGITHUB=0
for g in anthropic openai google ecosystem discovery; do
  [ "$(eval echo \${OK_$g:-0})" = "1" ] && NONGITHUB=1
done

{
  echo "# preflight — written by setup.sh"
  echo "checked_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
  for g in anthropic openai google github ecosystem discovery; do
    if [ "$(eval echo \${OK_$g:-0})" = "1" ]; then echo "$g: OK"; else echo "$g: BLOCKED"; fi
  done
  echo ""
  if [ "$NONGITHUB" = "0" ]; then
    echo "egress: BLOCKED"
    echo ""
    echo "  Every non-GitHub source failed — this is the environment's network policy"
    echo "  (Trusted covers package registries and GitHub only). Publish nothing, do"
    echo "  not write from memory, send one PushNotification listing the domains to"
    echo "  add under Network access → Custom → Allowed domains, then end the run."
  elif [ "${OK_anthropic:-0}" = "0" ] && [ "${OK_openai:-0}" = "0" ]; then
    echo "egress: CORE_BLOCKED"
    echo ""
    echo "  Neither Anthropic nor OpenAI is reachable — the two sources this site"
    echo "  exists for. Publish nothing; PushNotification with the missing domains."
  else
    echo "egress: OK"
    echo ""
    echo "  Any group marked BLOCKED above must be named on the page (.gaps line)"
    echo "  and in the push. Do not fill its slot from second-hand coverage."
  fi
  echo ""
  echo "probes:"
  printf '%s' "$RESULTS"
} > "$PREFLIGHT"

cat "$PREFLIGHT"
exit 0
