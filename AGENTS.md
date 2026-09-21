# AGENTS.md

給 Codex、Claude Code、Cursor、Antigravity 與其他自動化代理在本專案工作時的指引。產品與使用方式先讀 [`README.md`](README.md)；開發與驗收細節見 [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md)。

## 專案定位

這是 [`doggy8088/codex-reset-checker`](https://github.com/doggy8088/codex-reset-checker) 的 MIT License fork。
核心價值是從本機 `auth.json` 查詢 Codex/ChatGPT 手動重置點數與到期時程，並支援在需要時執行手動重置。

`origin` 是 `SanHsien/codex-reset-checker`（預設分支 `main`），`upstream` 是原作者 repo（預設分支 `main`）。
保留上游作者、MIT License 與產品程式。本 fork 的維護差異記在 [`FORK.md`](FORK.md) 與 [`docs/DECISIONS.md`](docs/DECISIONS.md)。

主要開發與完整驗收環境是 **Windows 11 + PowerShell**。本 fork 為純 Windows 維護線，所有測試與工作流程均在 Windows 原生環境執行。

## 硬性邊界

- 不提交使用者輸入檔案、專有文件、API key、token、私鑰、`auth.json` 或 `.env`。
- 不推送到 `upstream`。上游同步先跑 `python tools/check_upstream_updates.py`，逐筆審查後再 merge / cherry-pick；不盲目覆蓋 fork 文件與 Windows gate。
- 維護環境（`requirements-dev.txt`）僅安裝 pytest 與 ruff。
- 不把 fork 包裝成原創產品，不移除上游作者 Will 保哥或官方連結。

## 技術與資料流

- CLI 入口：`bin/codex-reset-checker.js`（Node.js 14+）。
- 腳本：`scripts/check-codex-rate-limit.ps1` 與 `scripts/check-codex-rate-limit.sh`。
- 測試：`test/codex-reset-checker.test.js`。
- `tools/`：fork 維護工具（Windows gate、上游檢查、相對連結檢查）。
- `tools/tests/`：維護契約測試。獨立於產品測試目錄。

## 開發原則

- 一般變更直接推 `origin/main`，不開功能分支、不開維護 PR。只有在需要他人審查、或改動風險高到值得先讓 CI 在 PR 上跑一輪時，才退回 **branch → PR → CI → merge**。
- 修 bug 先補可重現失敗測試，再做最小修正。
- 不為了套格式而大改上游程式；Ruff 只閘維護工具的 E9（語法）與 F（pyflakes）。
- 使用繁體中文回覆；使用者文件以繁中為主，公開入口同步維護 `README.en.md`。直接交付可驗證結果，避免冗長背景鋪陳。
- 一般變更提交前跑 `pwsh -NoProfile -File tools\dev_check.ps1` 作為驗證 gate。
- 提交訊息用 Conventional Commit。Dependabot 或外部 fork 的變更走 PR，讀 diff 並通過 CI 後再合併。
- `REVIEW.md` 是風險快照，不是每個一般 bug 的流水帳。
- 不 force-push `main`，不刪 `upstream` remote。

## 上游處理

1. `git fetch upstream main`
2. `python tools/check_upstream_updates.py --strict`
3. 逐筆判斷是否與繁中 README、Windows gate、發佈閘門或測試衝突。
4. 可同步的提交用 merge；只需要部分修正時 cherry-pick 或最小重做。
5. 跑 `pwsh -NoProfile -File tools\dev_check.ps1`
6. 採用／略過寫進 `docs/DECISIONS.md`，驗證後才推進 `tools/upstream_baseline.json`

Baseline 代表「已審查」，不代表「全部已合併」。

## 驗證

```powershell
pwsh -NoProfile -File tools\bootstrap_dev.ps1
```

沒有實際跑過 Windows gate，不要宣稱本機開發環境已可用。

## 文件責任

- `README.md` / `README.en.md`：公開產品與 fork 入口。
- `FORK.md`：與上游的關係、差異、同步方式。
- `NOTICE.md`：授權與 attribution。
- `docs/UPSTREAM.md`：upstream remote 與審查清冊。
- `docs/DEVELOPMENT.md`：本機開發與驗收指令。
- `docs/DECISIONS.md`：長期取捨。
- `REVIEW.md`：全庫風險快照。
- `CONTRIBUTING.md` / `SECURITY.md`：本 fork 的貢獻與安全回報流程。

## 對外邊界：PR 只打本 fork

- **PR、push、release 一律指向 `SanHsien/codex-reset-checker`。** 對上游 `doggy8088/codex-reset-checker` 開 PR、push 或發 release 需要維護者在當次對話明確同意回貢；「fork 一份」「建開發環境」「比照其他 repo」都不是同意。
- 根因是機制不是粗心：`gh` 在 fork clone 的**預設 repo 就是上游**，裸跑 `gh pr create` 必然打上去。每個 clone 先跑一次 `gh repo set-default SanHsien/codex-reset-checker`。
- 開 PR 仍明寫 `gh pr create --repo SanHsien/codex-reset-checker --base <分支> --head <分支>`，並**讀輸出的 URL**，owner 必須是 `SanHsien`。不是就立刻 `gh pr close` 留言道歉說明，再對 origin 重開。
