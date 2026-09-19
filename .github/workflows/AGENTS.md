# AGENTS.md（CI）

本目录工作流与测试流水线的经验沉淀。改 CI 前先读这里，别重复踩坑。

## 流水线结构

- `CI.yml`：唯一的测试流水线。`windows-latest` 上跑 3 个分片作业（matrix `shard`）；按改动增量选用例、并行构建/测试。
  用例与构建逻辑在 `tests/run.ps1` / `tests/lib/`，workflow 只负责触发、分片、缓存、报告。
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
workflow 里再手写一份 `hashFiles('src/*.ps1', ...)` 一定会漂移（漏递归、漏 `.cs`、漏组件划分），
导致 restore 到的旧缓存与构建键对不上、白存白取。让 workflow 向框架要指纹（`-PrintFingerprint`，返回全部
组件的并集）即可同源。单个构建的键则由 `Get-BuildKey` 用「该构建相关组件的指纹」算出，见
`$script:BuildComponentPatterns` 与 `Get-BuildFingerprintComponents`。

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

### 5. 分片数量多处要保持一致

`strategy.matrix.shard`、构建缓存键里的 `s${{ matrix.shard }}` 前缀、`Run tests` 里的
`-ShardCount 3` 是同一个 N，改一处必须同步改其余两处。分片归属由
`Get-ShardAssignment`（按全部用例的构建数贪心均衡）算，只取决于用例名/构建数，跨 run 稳定，
因此每片用固定前缀缓存键就能各自复用历史产物。纯测试用例按权重 1 参与均衡。
测试用例并发仍保持保守（GUI/私有控制台敏感），`contextmenu.toggle` 这类 `Serial` 用例只落在其中一片。

## 为什么有时会全量跑（不是 bug）

- 改 `tests/**` 或 `.github/workflows/**`：`Get-AffectedCases` 的安全网会选**全部用例**
  （`tests/lib/framework.ps1`）。
- 改产品源码：只失效**依赖该组件**的构建缓存（构建键 = 相关组件指纹 + 输入 + 参数）。命中
  `common` 组件的改动（`ps12exe.ps1`、`AstAnalyze`、`programFrames` 等）会失效所有构建，这是正确行为；
  只改 `CoreCompiler.ps1` 则只重建 Core 构建，改 `CodeDomCompiler.ps1`/`TinySharpCompiler.ps1` 只重建非 Core 构建。
- 改 `exe21sp.ps1`、`src/GUI`、`src/locale`、`src/WebServer` 等不进入产物的文件：构建指纹完全不变，
  全量命中缓存，只跑相关用例。
- 仅改测试用例、不动产品源码时，指纹不变，理论上可全量命中缓存——前提是缓存真的存下来了（见铁律 1）。

## 排查方法

```pwsh
gh run list --workflow CI.yml --limit 10
gh api repos/steve02081504/ps12exe/actions/jobs/<jobId> --jq '.steps[]|{name,started_at,completed_at,status}'
gh api repos/steve02081504/ps12exe/actions/jobs/<jobId>/logs > job.log   # 完成后才可取
gh api "repos/steve02081504/ps12exe/actions/caches" --jq '.total_count'  # 0 = 缓存没存过
```

日志里关注：`Cache not found ...`、`== 构建阶段 ... 缓存命中 N ==`、`测试阶段`。
本机做对照冷跑：`pwsh tests/run.ps1 -All -NoCache`（参考：i7-10870H 约 133s）。

## 已做过的优化（别重复做）

- 组件级构建指纹（Core / CodeDom / TinySharp / ps2exe / common），并把 exe21sp/GUI/WebServer/locale
  等不进入产物的文件移出构建指纹。实测改 `CoreCompiler.ps1` 只重建 4 个 Core 构建（48 中命中 44），
  改 `exe21sp.ps1` 则 18 个相关构建全命中。
- 构建阶段并行度默认 `min(CPU*2,8)`（本地从 181s 降到 133s），测试阶段仍 `min(CPU,4)`。
- 用例按构建数贪心均衡到 3 片，跨 runner 并行。

## 以后再优化（还没做）

- Core 构建的 `dotnet publish` 依赖 NuGet 还原，已加 `~/.nuget/packages` 缓存；若仍慢可考虑
  固定 TFM/RID 或预置 runtime pack，或复用持久 MSBuild 项目目录 + `--no-restore` 让 publish 增量。
- Windows runner 单构建仍比物理机慢 ~10×（进程创建 + Defender 扫描 + 共享盘）。`defender-exclusions`
  是 best-effort，`Set-MpPreference -DisableRealtimeMonitoring` 常被 tamper protection 拒绝；
  可加一步诊断确认实时防护是否真的关闭。
