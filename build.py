#!/usr/bin/env python3
"""Render the category pages and index from data/.

data/categories.json   — ordered list of categories (slug, file, name, question,
                         synthesis[], updated). synthesis items are short HTML
                         strings; they may use <strong>, <em>, <a href="#e-ID">.
data/entries.jsonl     — one source post per line (see validate() for fields).
data/changelog.jsonl   — {date, id, action: add|update, note}

The engine edits data only. HTML is always regenerated here, so a hand edit to
a page is overwritten on the next publish — that is deliberate.

    python3 build.py            # validate + render
    python3 build.py --check    # validate only
"""
from __future__ import annotations

import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).parent.resolve()
DATA = ROOT / "data"
SITE = "AI-native 转型笔记"
ALLOWED_TAGS = {"strong", "em", "a", "b", "code"}

REQUIRED = ["id", "url", "date", "org", "title", "category", "headline",
            "what_they_do", "numbers", "transferable", "caveats", "added"]


def load():
    cats = json.loads((DATA / "categories.json").read_text(encoding="utf-8"))
    entries = [json.loads(l) for l in (DATA / "entries.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    log = [json.loads(l) for l in (DATA / "changelog.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    return cats, entries, log


def check_inline_html(s: str, where: str, ids: set[str], errs: list[str]):
    for tag in re.findall(r"</?([a-zA-Z0-9]+)", s):
        if tag.lower() not in ALLOWED_TAGS:
            errs.append(f"{where}: tag <{tag}> not allowed (only {sorted(ALLOWED_TAGS)})")
    for ref in re.findall(r'href="#e-([^"]+)"', s):
        if ref not in ids:
            errs.append(f"{where}: link to #e-{ref} but no entry has that id")
    if "**" in s:
        errs.append(f"{where}: Markdown ** — use <strong>")
    if "{{" in s:
        errs.append(f"{where}: unfilled {{{{…}}}}")


def validate(cats, entries, log) -> list[str]:
    errs: list[str] = []
    slugs = [c["slug"] for c in cats]
    if len(set(slugs)) != len(slugs):
        errs.append("categories.json: duplicate slug")
    ids, urls = set(), set()
    for i, e in enumerate(entries, 1):
        w = f"entries.jsonl line {i} ({e.get('id', '?')})"
        for k in REQUIRED:
            if k not in e or e[k] in ("", None):
                errs.append(f"{w}: missing {k}")
        if e.get("id") in ids:
            errs.append(f"{w}: duplicate id")
        if e.get("url") in urls:
            errs.append(f"{w}: duplicate url")
        ids.add(e.get("id")); urls.add(e.get("url"))
        if not re.fullmatch(r"[a-z0-9-]+", e.get("id", "")):
            errs.append(f"{w}: id must be [a-z0-9-]+")
        if not str(e.get("url", "")).startswith("http"):
            errs.append(f"{w}: url must be http(s)")
        for k in ("date", "added"):
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(e.get(k, ""))):
                errs.append(f"{w}: {k} must be YYYY-MM-DD")
        for k in ("category", "category2"):
            if e.get(k) and e[k] not in slugs:
                errs.append(f"{w}: {k} '{e[k]}' not in categories.json")
        if not isinstance(e.get("numbers"), list):
            errs.append(f"{w}: numbers must be a list of verbatim sentences")
    for c in cats:
        if not c.get("synthesis"):
            errs.append(f"category {c['slug']}: empty synthesis")
        for j, s in enumerate(c.get("synthesis", []), 1):
            check_inline_html(s, f"category {c['slug']} synthesis #{j}", ids, errs)
    for e in entries:
        for k in ("headline", "what_they_do", "denominator_notes", "transferable", "caveats", "update_note"):
            if e.get(k):
                check_inline_html(e[k], f"entry {e['id']}.{k}", ids, errs)
    for r in log:
        if r.get("id") not in ids:
            errs.append(f"changelog: id {r.get('id')} not an entry")
    return errs


CSS = """
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,"SF Pro Display","Noto Sans SC",sans-serif;color:#dfe7ee;line-height:1.85;min-height:100vh;
  background:radial-gradient(1000px 520px at 8% -6%,rgba(79,209,197,0.10),transparent 60%),radial-gradient(900px 600px at 100% 0%,rgba(99,179,237,0.08),transparent 55%),linear-gradient(165deg,#0a0e12 0%,#0e141a 45%,#080b0e 100%);background-attachment:fixed}
.container{max-width:780px;margin:0 auto;padding:18px 20px 90px}
header{text-align:center;padding:44px 0 22px}
.tag{display:inline-block;font-size:0.75rem;color:#4fd1c5;font-family:"SF Mono",Menlo,monospace;letter-spacing:2px;border:1px solid rgba(79,209,197,0.42);padding:4px 13px;border-radius:20px;margin-bottom:16px;background:rgba(79,209,197,0.06)}
header h1{font-size:2rem;font-weight:800;line-height:1.32;background:linear-gradient(110deg,#9ae6dc 0%,#4fd1c5 45%,#63b3ed 92%);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
header h2{font-size:1rem;color:#93a3b1;margin-top:10px;font-weight:400}
header .date{font-size:0.8rem;color:#5d6b77;margin-top:14px;font-family:"SF Mono",Menlo,monospace}
a{color:#9ae6dc;text-decoration:none;border-bottom:1px dotted rgba(154,230,220,0.5)}
strong,b{color:#fff}
code{font-family:"SF Mono",Menlo,monospace;font-size:.86em;color:#cfe3f3}
.synthesis{margin:30px 0 10px;background:rgba(79,209,197,0.06);border:1px solid rgba(79,209,197,0.3);border-radius:14px;padding:20px 24px}
.synthesis h2{color:#4fd1c5;font-size:0.9rem;letter-spacing:2px;margin-bottom:12px;font-family:"SF Mono",Menlo,monospace}
.synthesis ol{padding-left:22px}
.synthesis li{margin-bottom:10px;font-size:0.96rem}
.entries-h{margin:46px 0 4px;color:#63b3ed;font-size:0.9rem;letter-spacing:2px;font-family:"SF Mono",Menlo,monospace}
.entry-item{margin:34px 0 0;padding-top:4px;scroll-margin-top:20px}
.entry-item h3::before{content:"";display:block;width:28px;height:2px;background:#4fd1c5;opacity:.75;margin-bottom:12px}
.entry-item h3{font-size:1.16rem;color:#fff;font-weight:700;line-height:1.45;margin-bottom:6px}
.meta{font-family:"SF Mono",Menlo,monospace;font-size:0.78rem;color:#7d8d9a;margin-bottom:12px}
.meta .org{color:#63b3ed;margin-right:8px}
.entry-item p{margin-bottom:10px;font-size:0.95rem}
.nums{margin:12px 0;border:1px solid rgba(99,179,237,0.3);border-radius:10px;background:rgba(99,179,237,0.05);padding:10px 18px}
.nums ul{list-style:none}
.nums li{font-size:0.9rem;padding:4px 0 4px 18px;position:relative}
.nums li::before{content:"#";position:absolute;left:0;color:#63b3ed;font-family:"SF Mono",Menlo,monospace}
.nums q{color:#cfe3f3}
.nums .note{display:block;color:#93a3b1;font-size:0.84rem;margin-top:4px}
.so{margin:12px 0;background:rgba(79,209,197,0.06);border:1px solid rgba(79,209,197,0.28);border-radius:10px;padding:10px 18px;font-size:0.93rem}
.so b{color:#9ae6dc}
.cold{margin:10px 0;border-left:2px solid rgba(240,160,100,0.7);padding:8px 16px;font-size:0.9rem;color:#e6cdb8;background:rgba(240,160,100,0.05);border-radius:0 8px 8px 0}
.cold b{color:#f0a064}
.upd{font-size:0.82rem;color:#f0c674;font-family:"SF Mono",Menlo,monospace;margin:6px 0}
.also{font-size:0.82rem;color:#7d8d9a}
.log{margin-top:48px;font-size:0.84rem;color:#93a3b1}
.log h2{color:#63b3ed;font-size:0.85rem;letter-spacing:2px;margin-bottom:10px;font-family:"SF Mono",Menlo,monospace}
.log li{list-style:none;padding:3px 0}
.log .d{font-family:"SF Mono",Menlo,monospace;color:#5d6b77;margin-right:8px}
footer{text-align:center;padding:48px 0 10px;font-size:0.8rem;color:#5d6b77;font-family:"SF Mono",Menlo,monospace}
.cats{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;margin-top:28px}
.cat{display:block;padding:16px 18px;border-radius:12px;background:rgba(255,255,255,0.03);border:1px solid rgba(79,209,197,0.16);border-top:3px solid #4fd1c5;border-bottom:1px solid rgba(79,209,197,0.16);color:inherit}
.cat:hover{background:rgba(255,255,255,0.06);border-top-color:#63b3ed}
.cat .n{font-family:"SF Mono",Menlo,monospace;font-size:0.74rem;color:#63b3ed}
.cat .t{display:block;font-size:1.05rem;font-weight:700;color:#eef3f7;margin-top:4px}
.cat .q{display:block;font-size:0.86rem;color:#8a9aa8;margin-top:4px;line-height:1.55}
.cat .top{display:block;font-size:0.86rem;color:#cfe3f3;margin-top:8px;line-height:1.55}
.recent{margin-top:40px}
.recent h2{color:#4fd1c5;font-size:0.88rem;letter-spacing:2px;margin-bottom:10px;font-family:"SF Mono",Menlo,monospace}
.recent li{list-style:none;padding:8px 0;border-top:1px solid rgba(79,209,197,0.1);font-size:0.92rem}
.recent .d{font-family:"SF Mono",Menlo,monospace;font-size:0.76rem;color:#63b3ed;margin-right:8px}
@media(max-width:640px){header h1{font-size:1.55rem}.cats{grid-template-columns:1fr}}
"""


def esc(s: str) -> str:
    return html.escape(s, quote=True)


def page(title: str, body: str) -> str:
    return (f'<!DOCTYPE html>\n<html lang="zh-CN"><head><meta charset="utf-8"/>'
            f'<meta content="width=device-width, initial-scale=1.0" name="viewport"/>\n'
            f"<title>{esc(title)}</title>\n<style>{CSS}</style></head><body>\n"
            f'<div class="container">\n{body}\n</div>\n</body></html>\n')


def entry_html(e: dict, cats_by_slug: dict, here: str) -> str:
    nums = ""
    if e.get("numbers"):
        items = "".join(f"<li><q>{esc(n)}</q></li>" for n in e["numbers"])
        note = f'<span class="note">口径：{e["denominator_notes"]}</span>' if e.get("denominator_notes") else ""
        nums = f'<div class="nums"><ul>{items}</ul>{note}</div>'
    upd = f'<p class="upd">更新于 {esc(e["updated"])}：{e.get("update_note", "")}</p>' if e.get("updated") else ""
    extra = []
    if e.get("commentary_url"):
        extra.append(f'<a href="{esc(e["commentary_url"])}" target="_blank">Simon Willison 的分析</a>')
    other = e.get("category2") if e.get("category") == here else e.get("category")
    if other and other in cats_by_slug:
        c = cats_by_slug[other]
        extra.append(f'也见 <a href="{c["file"]}#e-{e["id"]}">{esc(c["name"])}</a>')
    also = f'<p class="also">{" · ".join(extra)}</p>' if extra else ""
    return (f'<article class="entry-item" id="e-{e["id"]}">\n'
            f'<h3>{e["headline"]}</h3>\n'
            f'<div class="meta"><span class="org">{esc(e["org"])}</span>{esc(e["date"])} · '
            f'<a class="src" href="{esc(e["url"])}" target="_blank">{esc(e["title"])}</a></div>\n'
            f"{upd}<p>{e['what_they_do']}</p>\n{nums}\n"
            f'<div class="so"><b>能借鉴的：</b>{e["transferable"]}</div>\n'
            f'<div class="cold"><b>冷水：</b>{e["caveats"]}</div>\n{also}</article>')


def render(cats, entries, log):
    by_slug = {c["slug"]: c for c in cats}
    by_id = {e["id"]: e for e in entries}
    out = {}
    for c in cats:
        mine = sorted([e for e in entries if c["slug"] in (e["category"], e.get("category2"))],
                      key=lambda e: e["date"], reverse=True)
        syn = "".join(f"<li>{s}</li>" for s in c["synthesis"])
        rows = [r for r in log if r["id"] in by_id and c["slug"] in (by_id[r["id"]]["category"], by_id[r["id"]].get("category2"))]
        rows = sorted(rows, key=lambda r: r["date"], reverse=True)[:30]
        log_html = "".join(
            f'<li><span class="d">{esc(r["date"])}</span>{"新增" if r["action"] == "add" else "修改"} '
            f'<a href="#e-{r["id"]}">{esc(re.sub(r"<[^>]+>", "", by_id[r["id"]]["headline"]))}</a>'
            f'{"：" + esc(r["note"]) if r.get("note") else ""}</li>' for r in rows)
        body = (f'<header>\n<span class="tag">AI-NATIVE · {esc(c["slug"].upper())}</span>\n'
                f'<h1>{esc(c["name"])}</h1>\n<h2>{esc(c["question"])}</h2>\n'
                f'<div class="date">{len(mine)} 篇来源 · 更新于 {esc(c["updated"])} · BigCat</div>\n</header>\n'
                f'<section class="synthesis"><h2>// 目前能学到的</h2><ol>{syn}</ol></section>\n'
                f'<h2 class="entries-h">// 来源（新的在上）</h2>\n'
                + "\n".join(entry_html(e, by_slug, c["slug"]) for e in mine)
                + f'\n<section class="log"><h2>// 本页变更</h2><ul>{log_html}</ul></section>\n'
                f'<footer>BigCat · {SITE} · <a href="index.html">← 全部类别</a></footer>')
        out[c["file"]] = page(f'{c["name"]} — {SITE}', body)

    cards = []
    for c in cats:
        n = sum(1 for e in entries if c["slug"] in (e["category"], e.get("category2")))
        top = re.sub(r"<[^>]+>", "", c["synthesis"][0])
        cards.append(f'<a class="cat" href="{c["file"]}" data-updated="{esc(c["updated"])}"><span class="n">{n} 篇 · {esc(c["updated"])}</span>'
                     f'<span class="t">{esc(c["name"])}</span><span class="q">{esc(c["question"])}</span>'
                     f'<span class="top">{esc(top)}</span></a>')
    recent = sorted(log, key=lambda r: (r["date"], r["id"]), reverse=True)[:15]
    rec = "".join(
        f'<li><span class="d">{esc(r["date"])} · {"新增" if r["action"] == "add" else "修改"}</span>'
        f'<a href="{by_slug[by_id[r["id"]]["category"]]["file"]}#e-{r["id"]}">{esc(re.sub(r"<[^>]+>", "", by_id[r["id"]]["headline"]))}</a></li>'
        for r in recent)
    body = (f'<header>\n<h1>{SITE}</h1>\n'
            f'<h2>先进 AI lab 和一线团队自己是怎么变成 AI-native 的——流程、组织、度量、agent 运维——以及别的组织能借走什么</h2>\n'
            f'<div class="date">{len(entries)} 篇一手来源 · 每日检查，按类别新增或修改</div>\n</header>\n'
            f'<div class="cats">{"".join(cards)}</div>\n'
            f'<section class="recent"><h2>// 最近变更</h2><ul>{rec}</ul></section>')
    out["index.html"] = page(SITE, body)
    return out


def main():
    cats, entries, log = load()
    errs = validate(cats, entries, log)
    if errs:
        print("ERROR: data validation failed:")
        for e in errs:
            print("  -", e)
        sys.exit(1)
    if "--check" in sys.argv:
        print(f"OK: {len(cats)} categories, {len(entries)} entries, {len(log)} changelog rows")
        return
    for name, text in render(cats, entries, log).items():
        (ROOT / name).write_text(text, encoding="utf-8")
    print(f"built {len(cats)} category pages + index ({len(entries)} entries)")


if __name__ == "__main__":
    main()
