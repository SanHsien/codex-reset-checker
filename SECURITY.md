# 安全性政策

## 支援版本

本維護 fork 專注於 Windows-first 環境與維持上游同步。安全更新會以最新 `main` 為準。

| 版本 | 支援狀態 |
|---|---|
| `main` (latest) | :white_check_mark: |
| 舊版本 | :x: |

## 敏感資訊與隱私原則

- **嚴禁提交 Token 或金鑰**：`auth.json` 包含 OpenAI/ChatGPT 存取權限 Token，絕對不可提交至版本控制。
- **本機隔離**：CLI 僅於本機記憶體讀取 `auth.json`，不發送遙測、不持久化快取、不對未授權外部連線。
- **除錯遮罩**：所有例外與除錯訊息皆已進行敏感值遮罩處理。

## 回報安全漏洞

若在此維護 fork 發現專有的安全問題（如腳本權限、CI 設定洩漏等），請透過 GitHub Security Advisories 或私人聯繫維護者。

若漏洞屬於上游核心邏輯（如 OpenAI API 通訊、權限處理等），請優先回報至上游原作者專案：[`doggy8088/codex-reset-checker`](https://github.com/doggy8088/codex-reset-checker)。
