# 路線圖

> 本 repo 後續工作的單一真相源。做完一項，就在同一個 commit 刪掉那一列；新工作只加在這裡。
> 現況段的數字是 2026-10-30 依 `main` `ce41af4` 查的快照，開工前先重查 GitHub。

## 現況
這是 Windows 原生 Codex 額度查詢與手動重置工具的維護 fork，預設僅查詢（[README.md:34](README.md)）。2026-10-30 `gh` 查詢記錄 CI、CodeQL 最近結果成功，安全開啟告警為 0；Publish GitHub Pages 2026-10-17 的失敗是因為 repo 沒啟用 Pages；2026-11-02 決定不在 fork 重新發佈上游作者的介紹頁，workflow 只在上游 repo 執行（[docs/DECISIONS.md](docs/DECISIONS.md) 2026-11-02 段）；issues 停用而未查到 issue（2026-10-30 `gh` 查詢）。最新 release 為 v1.1.1，後續系統匣、安裝及錯誤視窗修正仍在 Unreleased（[CHANGELOG.md:3](CHANGELOG.md)）。

## 近期：可以直接動手
| 項目 | 為什麼 | 驗收方式 | 建議執行者 | 證據 |
| --- | --- | --- | --- | --- |
| 核對修正後的 Windows 安裝與移除路徑 | 深掃只測純函式與解析，未跑真實安裝／解除安裝 | 隔離使用者環境驗證單項 PATH 不黏連、系統匣讀取摘要、無 pwsh 可回退、查詢失敗保留視窗；移除後捷徑及安裝檔清乾淨且保留其他 PATH | 維護者 | [REVIEW.md:26](REVIEW.md)、[CHANGELOG.md:7](CHANGELOG.md)；深掃報告（2026-10-27）「範圍」 |

## 中期：等條件成立再做
| 項目 | 觸發條件 | 驗收方式 | 建議執行者 | 證據 |
| --- | --- | --- | --- | --- |
| 重評要不要離開 GitHub fork 網路 | 上游預設分支到 2026-12-25 仍沒有新 commit（最後一筆 2026-09-26，滿 90 天），或上游 archived／刪除 | 照 repo-fleet-ops PLAYBOOK §9 重判；改判「建議脫離」時先補齊 README／NOTICE 的來源段落、確認 release 資產可重建，再列給維護者確認（按鈕由維護者按） | Claude Opus | 2026-11-07 評估判「再觀察」：本線加了系統匣、安裝程式、執行檔與 Scoop，release 走到 v1.1.1，但產品執行路徑以上游為準（repo-fleet-ops `docs/FORK-NETWORK-REVIEW.md`）；查法 `gh api "repos/doggy8088/codex-reset-checker/commits?per_page=1"` |
| 發布包含 Windows 修正的執行檔 | 安裝與產品驗收通過，維護者授權發行 | 更新版本及 Scoop 所需資訊；重建執行檔並核對來源與雜湊，tag、Release、可下載資產一致，下載版 smoke 通過 | Codex | [AGENTS.md:78](AGENTS.md)、[CHANGELOG.md:3](CHANGELOG.md)、[tools/build_exe.ps1:50](tools/build_exe.ps1) |
| 收緊建置成功判斷 | 準備發布新版，或確認不再允許沿用舊執行檔 | 以編譯失敗／舊 exe 存在與 postject 非零案例驗證；失敗不可把舊產物標成本次成功，正常產物能執行 `--version` | Codex | [tools/build_exe.ps1:78](tools/build_exe.ps1)、[tools/build_exe.ps1:85](tools/build_exe.ps1)；深掃報告（2026-10-27）的既有取捨 |
| 重審 Ruff 延後版本 | freshness 顯示超過已審精度的新版本 | 用新版本跑 `ruff check --select E9,F tools` 與維護測試；保持下限的相容承諾，採用或續延附理由 | Codex | [docs/DECISIONS.md:52](docs/DECISIONS.md) |

## 刻意不做
| 不做什麼 | 理由 | 什麼情況下重新考慮 |
| --- | --- | --- |
| 用真帳戶執行 reset 當 smoke | reset 會消耗可用額度，查詢驗收不需要它；見 [README.md:34](README.md) | 維護者明確要求測試消耗額度的行為 |
| 引進舊 iCalendar 寫入功能 | 決策與產品邊界見 [docs/DECISIONS.md:27](docs/DECISIONS.md) | 維護者提出新的匯出需求與本機寫入規格 |

## 維護方式
每週依 [tools/upstream_baseline.json](tools/upstream_baseline.json) 審新增差量；歷史無共同祖先時用 cherry-pick 或最小重做，不改寫歷史。每月沿用 freshness 與 Dependabot 維護依賴；發行時除了 [AGENTS.md](AGENTS.md) 的 gate，必須核對下載產物及安裝路徑，理由記 [docs/DECISIONS.md](docs/DECISIONS.md)。
