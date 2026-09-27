# 決策日誌 (DECISIONS.md)

記錄本維護 fork 的架構取捨、長期方針與審查紀錄。

## 2026-09-12：初始化 Windows-first 維護型 Fork

- **背景**：原專案 [`doggy8088/codex-reset-checker`](https://github.com/doggy8088/codex-reset-checker) 由 Will 保哥維護，提供查詢 Codex/ChatGPT 額度、手動重置時程與觸發重置之 CLI 工具（npm 套件 `@willh/codex-reset-checker`）。
- **決策**：
  1. 建立 Windows 11 原生維護 Fork，提供繁體中文主入口與英文鏡像。
  2. 移植標準維護骨架：建立 Windows 專用門禁 `dev_check.ps1` 與 `bootstrap_dev.ps1`。
  3. 實施硬閘門：設定 `gh repo set-default SanHsien/codex-reset-checker` 並建立 `.cursor/rules/no-upstream-pr.mdc`。
  4. 鎖定上游基準水位：
     - Commit 水位：`76dbb0b2ce3def7e9c5832135d1c84382ea2499c`（短 SHA `76dbb0b`，v1.0.1）
     - PR 水位：`4`
     - Issue 水位：`0`
     - 審查日期：`2026-09-12`
  5. 安全隔離：硬化 `.github/workflows/ci.yml`，避免在 fork 上觸發向 npm publish 或誤建立 Release。
  6. 清理遠端分支：移除 `origin` 上的過期分支 `doggy8088-initialize-design-context`，僅保留 `main` 分支。

## 2026-09-12：上游 PR #4 與特徵分支評估

- **上游分支 `doggy8088-initialize-design-context` 評估**：
  - 分支核心提交 `dfec056`（產品首頁）已在 2026-07-14 併入 `main`（提交 `49ab833`），僅差上游主動清理的 `.now.json`。
  - **結論**：不引進，維持上游 `main` 為唯一追蹤分支。
- **上游 PR #4 評估**：
  - PR `#4`（`feat(ics): 支援手動重置額度複選與 iCalendar 匯出`）由作者 Benknightdark 於 2026-07-26 自行關閉（CLOSED）並刪除分支。
  - 評估：該功能引入本機磁碟寫入 `.ics` 檔案與開啟資料夾行為，違反專案「唯讀查詢、不修改任何本機檔案」之核心安全政策；且其 base 停留於舊版 0.6.x，與 1.0.1 現行架構大幅脫節。
  - **結論**：不予引進，維持現狀並鎖定水位至 #4。

## 2026-09-12：標籤精簡與代碼缺陷修復

- **標籤清理**：刪除遠端 `origin` 與本機 24 個過期 tags（`v0.1.0` ~ `v1.0.0`），僅保留最新正式版本標籤 `v1.0.1`。
- **缺陷修復 (R-04)**：修復 `bin/codex-reset-checker.js` 跨 chunk 多位元組 UTF-8 字元截斷問題，以 `Buffer.concat(chunks).toString('utf8')` 保證資料流完整。
- **相容性修復 (R-05)**：修復 `scripts/check-codex-rate-limit.ps1` 在現代 PowerShell 7+ (pwsh) 下未能解析 HTTP 狀態碼之問題。
