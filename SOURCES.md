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

### 社区一手（2026-11-12 起升为一线）
- https://simonwillison.net/atom/everything/ — Simon Willison。**他自己的东西可以直接当出处**：亲手做的实验、工具发布（llm、datasette 插件等）、带数据的测评、他对官方帖的独立分析。他只是转述某个官方帖时，出处放官方原帖，他的补充判断可以写进 `.cold` 或正文并另附他的链接。
- https://news.ycombinator.com/ 首页（`hn.algolia.com/api/v1/search?tags=front_page`，再按 `points` 和标题里的 AI / LLM / agent / Claude / GPT / Codex 等词筛）。**HN 是入口，出处是它指向的那篇文章**：可以是任何团队或个人工程师的一手复盘（「我们用 agent 迁移了 40 万行代码」这类），不限于大厂。讨论串里有实质性的反证或补充数据时，可以在 `.cold` 里附讨论串链接。

社区来源同样要过第 2 节的判据，并且**必须是一手经验或一手数据**：作者自己做过、测过、量过。纯观点文、转述、「AI 将改变一切」类评论一律 skip。

HN 指向的文章打不开（域名被环境挡、付费墙、403）→ 这条 skip，**不要凭标题或讨论串里的转述来写**。
