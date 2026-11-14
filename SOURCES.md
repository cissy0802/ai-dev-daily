# SOURCES.md — 每天要扫的信源

BigCat 维护这份清单，引擎**只读不改**（`publish.sh` 会拦下改动）。想加/删信源直接改这里。

要找的是**组织自己怎么用 AI 干活**的一手信息（见 CLAUDE.md 第 2 节），不是产品新闻。

读法：优先 RSS / sitemap；页面用 `curl -sSL -A '<浏览器 UA>'`（UA 见 `setup.sh`）。**任何站点出现人机验证 / bot 防护（Cloudflare challenge、CAPTCHA 等）一律不绕过**：换 RSS、官方存档或 Web Archive，都没有就 skip。

## Anthropic（最高产）
- https://claude.dev/blog — **开发者博客，不在任何 sitemap 里**；Claude Code 团队的评审、skills、性能、多 agent 实践多半发在这里
- https://www.anthropic.com/research — 工程帖已迁到 `/research/`（`/engineering/*` 会重定向过来），条目 URL 一律记 `/research/` 版本
- https://www.anthropic.com/institute — 「AI 怎么改变 Anthropic 自己」的度量研究（部分帖子正文无日期，日期取这个列表页，并在 caveats 注明）
- https://www.anthropic.com/news
- https://claude.com/blog 、https://claude.com/resources/articles — 「Anthropic 某团队怎么用 Claude」系列（销售、财务、市场、法务、数据）

## OpenAI
- https://openai.com/news/rss.xml — 发现入口，标题/日期/摘要都在 feed 里。**openai.com 的页面有 Cloudflare 人机验证（403 + `cf-mitigated: challenge`），不要设法绕过**：不用 r.jina.ai 之类的渲染代理，不换 UA 硬闯。读全文只用 Web Archive 的存档副本：先查 `https://archive.org/wayback/available?url=<原 URL>`，有存档就读 `archived_snapshots.closest.url`；条目 `url` 仍记原 URL。
  - 还没有存档的新帖：本次只记 `skip`（标题写「待存档」），**不按摘要写条目**；它会在之后几天的 14 天回看窗口里被重新看到——账本里 skip 过的 URL 本会被跳过，所以「待存档」是唯一例外：标题以「待存档」开头的 skip 行，下次有存档时可以收录（写一行新的 pub）；仍无存档就什么都不记，等下一天。
- https://developers.openai.com/blog — 「OpenAI 内部怎么用 Codex」类

## 其他大厂工程博客（只收第一手内部实践）
- https://engineering.fb.com/ — Meta
- https://www.microsoft.com/insidetrack/blog/ 、https://devblogs.microsoft.com/ — Microsoft 内部 IT / 工程
- https://github.blog/engineering/ — GitHub 自己的工程实践
- https://research.google/blog/ 、https://deepmind.google/discover/blog/ — Google 一手材料很少，多为高管口径；只收有内部数据的

## 社区一手（2026-11-12 起升为一线）
- https://simonwillison.net/atom/everything/ — Simon Willison。**他自己的东西可以直接当出处**：亲手做的实验、带数据的测评、他对 lab 工作方式的独立分析。他只是转述某个官方帖时，出处放官方原帖，他的链接记进 `commentary_url`。
- HN 首页（`https://hn.algolia.com/api/v1/search?tags=front_page`，再按标题里的 AI / LLM / agent / Claude / Codex 等词筛）。**HN 是入口，出处是它指向的那篇文章**：可以是任何团队或个人工程师的一手复盘（迁移、评审流程、CI、度量，包括负面结果），不限大厂。

社区来源同样要过 CLAUDE.md 第 2 节的判据，并且**必须是一手经验或一手数据**：作者自己做过、测过、量过。纯观点文、转述、预测一律 skip。

链到的文章打不开（被挡、付费墙、403）→ skip，**不要凭标题或讨论串里的转述来写**。推文/X 长文可用 `https://api.fxtwitter.com/<user>/status/<id>` 读全文。
