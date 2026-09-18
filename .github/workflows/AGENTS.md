# AGENTS.md（CI）

本目录工作流与测试流水线的经验沉淀。改 CI 前先读这里，别重复踩坑。

## 流水线结构

- `CI.yml`：唯一的测试流水线。单个 `windows-latest` 作业；按改动增量选用例、并行构建/测试。
  用例与构建逻辑在 `tests/run.ps1` / `tests/lib/`，workflow 只负责触发、缓存、报告。
- `Publish.yml` / `AV-auto-test.yaml`：其它 Windows 作业，同样走 `defender-exclusions`（见下）。
- `static.yml` 与 issue bot 系列跑在 `ubuntu-latest`，与编译无关，无需改动。

## 铁律

### 1. 缓存必须 restore/save 拆分，且 `if: always()`

`actions/cache@v4` 只在**作业成功**时保存缓存。只要有一个用例红（例如早先的
`contextmenu.toggle`），缓存就永远存不下来 → 每次 push 都全量冷构建，慢到 30 分钟以上。
所以统一用：

```yaml
- uses: actions/cache/restore@v4
  id: xxx
  ...
- uses: actions/cache/save@v4
  if: always() && steps.xxx.outputs.cache-hit != 'true'
  ...
```

save 前确保目录存在（空目录在有 `always()` 的步骤里先 `New-Item -Force`），否则 path 校验告警。

### 2. 缓存键用 `pwsh tests/run.ps1 -PrintFingerprint`，不要手写 `hashFiles` 列表

构建缓存键由 `Get-SourceFingerprint`（`tests/lib/common.ps1`）决定，它是**编译输入的唯一真源**。
workflow 里再手写一份 `hashFiles('src/*.ps1', ...)` 一定会漂移（漏递归、漏 `.cs/.fbs/.json`），
导致 restore 到的旧缓存与构建键对不上、白存白取。让 workflow 向框架要指纹即可同源。

### 3. Windows runner 必须加 Defender 排除

GitHub 托管 Windows runner 默认开实时防护。本流水线会拉起 ~百个 `pwsh`/`csc`/`dotnet` 进程并
频繁生成 exe/临时文件，正是实时扫描最慢的场景；冷构建阶段实测比物理机慢 ~13×。
统一用复合动作：

```yaml
- uses: actions/checkout@v4   # 复合动作从仓库内加载，必须先 checkout
- name: Windows speedup
  uses: ./.github/actions/defender-exclusions
```

新增 Windows 作业时照抄这两行。Ubuntu 作业不需要。

### 4. 同一 ref 并发运行要取消旧的

`CI.yml` 顶部的 `concurrency: { group: ..., cancel-in-progress: true }` 会取消同 ref 的旧运行。
好处：不排队占 runner，也不会因为人工取消一堆 run 而丢掉本可落盘的缓存。

## 为什么有时会全量跑（不是 bug）

- 改 `tests/**` 或 `.github/workflows/**`：`Get-AffectedCases` 的安全网会选**全部用例**
  （`tests/lib/framework.ps1`）。
- 改任何产品源码：全局指纹变化 → **所有**构建的缓存键失效，必须重建（构建键 = 全局指纹 + 输入 + 参数）。
- 仅改测试用例、不动产品源码时，指纹不变，理论上可全量命中缓存——前提是缓存真的存下来了（见铁律 1）。

## 排查方法

```pwsh
gh run list --workflow CI.yml --limit 10
gh api repos/steve02081504/ps12exe/actions/jobs/<jobId> --jq '.steps[]|{name,started_at,completed_at,status}'
gh api repos/steve02081504/ps12exe/actions/jobs/<jobId>/logs > job.log   # 完成后才可取
gh api "repos/steve02081504/ps12exe/actions/caches" --jq '.total_count'  # 0 = 缓存没存过
```

日志里关注：`Cache not found ...`、`== 构建阶段 ... 缓存命中 N ==`、`测试阶段`。
本机做对照冷跑：`pwsh tests/run.ps1 -All -NoCache`（参考：i7-10870H 约 200s；CI 全冷约 34min）。

## 以后再优化（还没做）

- Core 构建的 `dotnet publish` 依赖 NuGet 还原，已加 `~/.nuget/packages` 缓存；若仍慢可考虑
  固定 TFM/RID 或预置 runtime pack。
- 构建键目前是「全局指纹」，改 `CoreCompiler.ps1` 会连带重建走 CodeDom/TinySharp 的构建。
  若冷构建仍不可接受，可拆分组件级指纹（Core / CodeDom / TinySharp / 公共）来缩小重建范围。
