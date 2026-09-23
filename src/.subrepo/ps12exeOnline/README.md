# ps12exe Online

A small ASP.NET Core web service that compiles a PowerShell script into a standalone
executable with [ps12exe](../../../ps12exe.ps1). The browser is a single page; the server
exposes a JSON API and streams the generated `a.exe` back.

It replaces the old ASP.NET WebForms draft (`index.aspx`), which could not build on
.NET Framework 4.8 and duplicated the logic already proven by `src/WebServer/main.ps1`.

## How it works

1. `POST /api/compile` accepts `{ "content": "<script>", "locale": "en-US" }`.
2. The request is rate-limited per client IP and checked against `Compiler:MaxScriptBytes`.
3. `CompilerService` hashes the script (SHA-256) and serves `a.exe` from the cache when possible.
4. Otherwise it writes the script to a temp file and spawns `powershell.exe -File scripts/compile.ps1`,
   which imports `ps12exe.psm1` and runs `ps12exe -Sandbox` for untrusted clients. The child
   process is killed after `Compiler:CompileTimeoutSeconds`.
5. Content-different requests wait for a free compile slot (`Compiler:MaxConcurrency`),
   returning `503 ServerBusy` if none frees up in time.

## Requirements (host)

- Windows. ps12exe's default `Framework4.0` target compiles with the .NET Framework compiler,
  so the service must run on Windows (Azure App Service **Windows**, or any Windows Server).
- Windows PowerShell 5.1 (`powershell.exe`) — the worker prefers it and falls back to `pwsh`.
- .NET 10 runtime (framework-dependent) or publish self-contained.

## Run locally

```powershell
dotnet run --project src/.subrepo/ps12exeOnline
# http://localhost:5000
```

In development the service finds `ps12exe.psm1` by walking up from the project directory,
so no extra setup is needed inside this repository.

## Publish for deployment

`build.ps1` runs `dotnet publish` **and bundles the compiler** (`compiler/ps12exe.psm1`,
`compiler/src`, `compiler/img`) so the output folder is self-contained:

```powershell
# -> src/.subrepo/ps12exeOnline/publish
pwsh src/.subrepo/ps12exeOnline/build.ps1 -Zip
```

The generated `web.config` (produced by the SDK) points IIS/ANCM at the app; `compiler/` is
resolved relative to the content root automatically.

## Deploy to Azure App Service (Windows)

1. Create a **Windows** App Service (Linux cannot run the .NET Framework compiler).
2. Set the stack to **.NET 10**.
3. `pwsh src/.subrepo/ps12exeOnline/build.ps1 -Zip` and deploy the zip with
   `az webapp deploy --resource-group <rg> --name <app> --src-path .\publish.zip --type zip`,
   or `az webapp deploy --src-path .\publish --type static` for the folder.
4. Optional app settings (see the table below), e.g. `Compiler__MaxConcurrency=2` on a small plan.

> Because compilation spawns a child PowerShell process, use a plan with enough CPU/memory for
> the number of concurrent compiles you allow. On the free/shared tier keep `MaxConcurrency` at 1–2.

### Useful app settings

| Setting | Purpose |
| --- | --- |
| `Compiler__MaxConcurrency` | Concurrent compiles per instance |
| `Compiler__CompileTimeoutSeconds` | Kill a compile after N seconds |
| `Compiler__RequestsPerMinute` | Per-IP fixed-window rate limit |
| `Compiler__MaxScriptBytes` | Maximum script size |
| `Compiler__MaxCacheBytes` / `Compiler__CacheCleanupMinutes` | Cache size cap and cleanup interval |
| `Compiler__ModulePath` | Explicit path to `ps12exe.psm1` (defaults to bundled `compiler/`) |
| `Compiler__PowerShellPath` | Explicit `powershell.exe` / `pwsh` path |
| `Compiler__CacheDirectory` | Persistent cache directory (defaults to `%HOME%\data` on App Service) |
| `Compiler__TrustLoopback` | `true` (default) skips sandbox only for loopback requests |

The real client IP is read from `X-Forwarded-For`; `ForwardedHeaders` is configured with
`ForwardLimit = 1` and the default proxy allow-list cleared so the platform-injected value wins.

## API

- `POST /api/compile` — JSON `{ content, locale? }` → `200` binary `a.exe`, or JSON error
  `{ error, message }` with `400` (empty), `413` (too large), `429` (rate limited),
  `503` (busy), `504` (timeout) or `500` (compile failed).
- `GET /healthz` — `{ "status": "ok" }`.
- `GET /favicon.ico`, `GET /bgm.mid` — page assets.
- `GET /` — the single-page UI.

## Security notes

- Untrusted input is compiled with `-Sandbox`; pragma sub-expressions are additionally restricted
  by ps12exe's own command/variable allow-list, and `Signing.Certificate`, `Build.TempDir` etc.
  are rejected in guest mode.
- Compilation runs out-of-process with a hard timeout and process-tree kill.
- The API never accepts an output path or arbitrary PowerShell arguments from the client.
