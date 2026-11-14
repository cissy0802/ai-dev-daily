# CLAUDE.md — AI-native 转型笔记 · ai-dev-daily

这是云端 routine 的执行说明。你是引擎本身，**自主完成、不等任何人确认**。当前工作目录已挂载本仓库（仓库名沿用 `ai-dev-daily`，站名已改为「AI-native 转型笔记」）。

## 定位

读者是一家大型非 AI-lab 科技公司的资深工程 TLM，正在带团队做 AI-native 转型。她要学的是：**先进 AI lab（Anthropic、OpenAI、Google DeepMind 等）和一线工程团队自己是怎么变成 AI-native 的，别的组织能从中借走什么。**

这**不是新闻站**。模型发布、降价、API 变化、新功能本身都**不重要**，除非帖子里有关于「这个组织自己怎么干活」的一手信息（比如一篇模型发布帖里顺带说了「核心代码库九成的合并改动由 Claude 写」——那一句就要，其余不要）。

站点是一个**按类别组织、持续修订的知识库**。每天的检查做三件事之一：**新增**一条来源、**修改**已有条目（新数据、更正、后续进展）、**修订**某个类别的综合结论。什么都不够格就什么都不做。

## 数据和页面

- `data/categories.json`：类别清单（`slug`、`file`、`name`、`question`、`synthesis`、`updated`）。**类别的增删改名是 BigCat 的决定**，引擎只改 `synthesis` 和 `updated`。
- `data/entries.jsonl`：每行一篇来源。字段：
  - `id`（`[a-z0-9-]+`，短而可读，如 `anthropic-90pct-merged-changes`）、`url`、`date`（原帖日期）、`org`、`title`（原帖原标题）
  - `category`（必填）、`category2`（可选，确实同时属于两类才填）
  - `headline`：中文一句话，**这条来源教会我们什么**（不是原标题的翻译）
  - `what_they_do`：2–4 句，这个组织具体做了什么、改了什么
  - `numbers`：原帖里带数字的句子，**逐字复制的英文原句**，一个字不改；没有就 `[]`
  - `denominator_notes`：中文，每个数字的口径、缺什么分母
  - `transferable`：别的组织能借走什么、前提是什么
  - `caveats`：厂商自报、单一团队、lab 特有条件等
  - `added`（加入本站的日期）；修改过的条目另加 `updated` 和 `update_note`
  - `commentary_url`（可选，Simon Willison 等的独立分析）
  - 文本字段里只允许 `<strong>` `<em>` `<b>` `<code>` 和站内锚点 `<a href="#e-ID">`，不写 Markdown。
- `data/changelog.jsonl`：每次新增/修改一行 `{"date", "id", "action": "add"|"update", "note"}`，只追加。
- `seen.tsv`：看过的 URL 账本，`date	status	url	title`，只追加。
- **页面全部由 `python3 build.py` 从数据生成**，不要手改任何 `.html`（下次构建会覆盖）。

## 0. 开工：自己跑 `bash setup.sh`

每次都自己跑，别信环境留下的 `.preflight`。
- `egress: BLOCKED` / `CORE_BLOCKED` → 立刻停，不改任何文件，PushNotification 列出 BLOCKED 的域名，结束。**绝不凭记忆或二手报道写。**
- 部分组 BLOCKED → 照做，推送里注明哪组没读到。

读法：优先 RSS / changelog；页面用 `curl -sSL -A '<UA>'`（UA 见 `setup.sh`），`python3` 去标签后存 `/tmp/` 再读。

## 1. 收集候选

- 按 `SOURCES.md` 扫所有信源（**只读不改**）。
- **时间窗**：发布在过去 **72 小时**内的帖子；lab 的工程博客（anthropic.com/engineering 等）往回看 **14 天**，防止前几天漏掉。
- `seen.tsv` 里出现过的 URL（pub 或 skip）一律跳过（唯一例外：标题以「待存档」开头的 OpenAI skip 行，见 `SOURCES.md`）——**例外**：已收录来源的同一组织发了后续帖，那是新 URL，照常处理。
- 二手线索（HN、Simon）必须回到它指向的原文；打不开就 skip，不凭标题或评论写。

## 2. 判断：够不够格

问一句：**这篇有没有关于某个组织「自己怎么用 AI 干活」的一手信息，能让一个正在转型的工程组织学到东西？**

够格的形状：内部使用数据（多少代码/PR 由 agent 写）、流程怎么变了（评审、规划、on-call、发布）、组织和角色怎么变了、怎么度量（包括负面结果）、内部 agent 运维（并行、长任务、harness、上下文/记忆）、内部的护栏和事故、非工程职能的变化、有内部数据支撑的推广方法论。

不够格：产品发布、模型发布、定价、API 变化、benchmark、融资、政策、观点文、预测、厂商写别家客户的案例。**一篇不够格的帖子里有一句够格的数据 → 只收那一句**（`what_they_do` 写清它出自哪类帖子）。

## 3. 动作：新增 / 修改 / 修订

对每个够格的候选，先 `grep` 一下 `data/entries.jsonl`，看是不是已有条目讲的同一件事：

- **新的事 → 新增条目**。读完原帖全文，按上面的字段写。`numbers` 只能复制原句。归到最贴切的一个类别。
- **已有条目的后续 → 修改那一条**：同一组织更新了数字、发了更正、说明了后续结果、或者新证据推翻了旧条目的某句话。改正文，填 `updated`（今天）和 `update_note`（一句话说改了什么、依据是哪篇——新依据 URL 写进 `update_note` 的文字里，并在 `seen.tsv` 记一行 `skip`）。**不删条目、不改 url。**
- **然后看综合结论**：新增或修改的条目会不会改变该类别 `synthesis` 里的某一条？
  - `synthesis` 是 3–7 条「目前能学到的」，每条一句到两句，**必须用 `<a href="#e-ID">` 引用至少一个条目**，并在末尾标证据强度：`（多个组织）` / `（单一组织）` / `（厂商自报）`。
  - 新证据**支持**某条 → 把新条目加进引用，必要时升级证据强度。
  - 新证据**冲突** → 改写那条，写清分歧在哪，changelog 的 note 里说明。
  - 真正的新结论 → 加一条；超过 7 条就合并最相近的两条。
  - 改了 synthesis 就把该类别的 `updated` 设为今天。
- 每个新增/修改的条目在 `changelog.jsonl` 追加一行。

**宁缺毋滥**：没有任何够格的候选 → 不改任何文件、不跑 `publish.sh`，PushNotification `AI-native 转型笔记今日无变更：扫了 N 个信源`，结束。

## 4. 记账

- 收录为新条目的 URL → `seen.tsv` 一行 `pub`（与条目 `url` 逐字相同）。
- 看过但不够格、或用于修改旧条目的 URL → `skip`。
- changelog 类信源（`CHANGELOG.md`、`/changelog`）URL 每天一样，必须加真实存在的版本/日期锚点：`…/CHANGELOG.md#2.1.323`。

## 5. 发布

1. `python3 build.py --check`，有错就改数据。
2. `./publish.sh`：它核对账本、changelog、条目不被删除，然后重新构建全部页面并推送。报错就按报错改，**不绕过闸门**（不改 `publish.sh`/`build.py`、不手动 `git push`）。
3. **不要**手动加 `comments.js` 等共享脚本（GitHub Action 自动注入）。

## 6. 写作

- 口语化、短句、信息密度高；不写元叙述，不写腰封词（「重磅」「颠覆」「王炸」）。
- 产品名、术语保持英文（agent、PR、eval、harness、context window）。
- **厂商的数字是厂商的数字**：没分母、没时间段、利益相关，都要在 `denominator_notes` / `caveats` 里说出来。这不是唱反调，是读者做决策需要的。
- `transferable` 要具体到动作和前提（「先在一个团队把 PR 评审改成 X，前提是已有 Y」），不写「值得关注」「值得借鉴」。
- 不假设读者的年龄、性别和身份。

## 7. 完成后

PushNotification（`status:"proactive"`，一行 <200 字，无 markdown）：
`AI-native 转型笔记：新增 N 条、修改 M 条 · <最重要那条的 headline> · hub.cissychen.com/ai-dev-daily`
