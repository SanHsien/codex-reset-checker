# REVIEW.md - 全庫風險快照

本文件記錄 `SanHsien/codex-reset-checker` 的安全、相容性與維護風險快照。

## 結論

全庫完成 Windows-first 維護骨架初始化、安全硬化、代碼缺陷修復與雙重測試驗證。核心產品 47 項單元測試、CLI 版本與說明檢驗全數通過。已修復跨 chunk 多位元組 UTF-8 解碼截斷缺陷與 PowerShell 狀態碼捕獲相容性；遠端與本地過期標籤清理完成，僅保留最新版本 v1.0.1。

## 已修 findings

1. **上游 CI 自動發佈非預期觸發風險 (R-01)**：
   - **現象**：上游原本的 `.github/workflows/ci.yml` 在 `main` 分支發生變更時，會透過 Trusted Publisher 自動執行 `npm publish` 與建立 GitHub Release。
   - **修復**：在本 fork 的 CI 工作流中，加入 repository 限制守衛（`if: github.repository == 'doggy8088/codex-reset-checker'`），並為本 fork 建立 Windows 原生專用測試矩陣與 Windows gate 驗收，杜絕意外向 npm 發佈。
2. **缺少 .gitignore 導致敏感資料風險 (R-02)**：
   - **現象**：上游未附帶 `.gitignore`，本機使用時容易不慎將測試用的 `auth.json`、`.env`、虛擬環境或報告提交進版控。
   - **修復**：新增完整的 `.gitignore`，明確忽略 `auth.json`、`.env`、`node_modules`、`.venv` 及各類快取報告。
3. **gh pr create 預設打向上游風險 (R-03)**：
   - **現象**：GitHub CLI 在 fork 下預設 PR 目標為上游。
   - **修復**：執行 `gh repo set-default SanHsien/codex-reset-checker`，並新增 `.cursor/rules/no-upstream-pr.mdc` 與多處維護文件警語。
4. **多位元組 UTF-8 字元在 HTTP chunk 邊界截斷損壞 (R-04)**：
   - **現象**：`bin/codex-reset-checker.js` 原使用字串疊加方式累積每個 chunk 的 `buffer.toString('utf8')`。若中文字元（3 bytes）或特殊符號在傳輸時恰好跨越兩個 chunk，前一半 byte 會被強制轉換為 Replacement Character `\uFFFD`，造成回應內容損壞或 JSON 解析失敗。
   - **修復**：改為陣列累積 Buffer，於資料流結束時統一執行 `Buffer.concat(chunks).toString('utf8')`，並在 `test/codex-reset-checker.test.js` 補充跨 chunk UTF-8 測試案例。
5. **PowerShell 7+ (pwsh) 異常時未能正確捕獲 HTTP 狀態碼 (R-05)**：
   - **現象**：`scripts/check-codex-rate-limit.ps1` 原僅檢查 `$_.Exception.Response -is [System.Net.WebException]`，在現代 PowerShell 7+ (pwsh) 使用 `HttpClient` 拋出的 `HttpRequestException` 下條件恆為假，導致 HTTP 401/403/500 等狀態碼遺失。
   - **修復**：改善狀態碼讀取邏輯，優先提取 `$_.Exception.Response.StatusCode`，若無再提取 `$_.Exception.StatusCode`，完整相容 Windows PowerShell 5.1 與 PowerShell 7+。

## 接受、不改契約

1. **非公開 API 依賴**：
   - `/wham/usage` 與 `/wham/rate-limit-reset-credits/*` 屬於 OpenAI 未公開的內部端點，隨時可能有結構變更。本 fork 接受上游現有設計，不擅自修改端點協定。
2. **終端 UTF-8 / ANSI 顏色輸出**：
   - 在舊版 Windows 主控台或未啟用 VT100 支援時，方框繪製字元可能退化。Windows 11 Windows Terminal 為標準目標環境，維持預設行為。

## 尚未宣稱範圍

1. **macOS / Linux 平台原生包裝**：
   - 本 fork 為 Windows-first 維護線，雖然 Node.js 與 Shell 腳本具備跨平台能力，但 CI 與 gate 以 Windows 原生環境為主要保證。
