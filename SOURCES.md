# SOURCES.md — 每天要扫的信源

BigCat 维护这份清单，引擎**只读不改**（`publish.sh` 会拦下改动）。想加/删信源直接改这里。

读法：优先 RSS / changelog 原文件（结构稳定、有日期）；页面用 `curl -sSL -A '<浏览器 UA>'`（UA 见 `setup.sh`），WebFetch 被挡时换 curl。

## 一线：每天必扫（发现 + 一手出处）

### Anthropic
- https://www.anthropic.com/news — 公司新闻、产品发布
- https://www.anthropic.com/engineering — **工程博客，重中之重**（内部怎么用 Claude 开发、带数字的实践复盘）
- https://claude.com/blog — 产品博客（Claude Code、Claude for Sheets/Excel/Chrome 这类集成）
- https://platform.claude.com/docs/en/release-notes/overview — API / 平台更新
- https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md — Claude Code 版本更新（只挑有意义的功能，不逐条抄版本号）

### OpenAI
- https://openai.com/news/rss.xml — 新闻 RSS（openai.com 页面常被 Cloudflare 挡，先走 RSS）
- https://developers.openai.com/changelog — API / 开发者平台更新
- https://github.com/openai/codex/releases — Codex CLI 发布（走 `api.github.com/repos/openai/codex/releases?per_page=10`）

### Google
- https://developers.googleblog.com/ — Gemini API / 开发工具
- https://deepmind.google/discover/blog/ — 研究与模型发布（只挑开发相关）

### 开发工具生态
- https://github.blog/changelog/feed/ — GitHub（Copilot、Actions 等）
- https://cursor.com/changelog — Cursor

## 二线：只用来发现，不能当唯一出处

- https://simonwillison.net/atom/everything/ — 高信噪比的整理者，常第一时间读完官方帖
- https://news.ycombinator.com/ — 看当天开发者真正在讨论什么（`hn.algolia.com/api/v1/search?tags=front_page`）

在二线看到线索 → **必须回到一线找到原帖**，页面上的出处链接只放原帖。找不到原帖的不写。
