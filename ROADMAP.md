# 路線圖

> 本 repo 後續工作的單一真相源。做完一項，就在同一個 commit 刪掉那一列；新工作只加在這裡。
> 現況段的數字是 2026-10-29 依 `main` `ae9d85be9da6` 查的快照，開工前先重查 GitHub。

## 現況
這是 Windows 原生 Codex 額度查詢與手動重置工具的維護 fork，預設僅查詢（[README.md:34](README.md)）。2026-10-29 `gh` 查詢記錄 CI、CodeQL、Dependency freshness、Upstream check 最近結果成功，安全開啟告警為 0；Publish GitHub Pages 最近一次失敗，原因未附，issues 停用而未查到 issue（2026-10-29 `gh` 查詢）。最新 release 為 v1.1.1，後續系統匣、安裝及錯誤視窗修正仍在 Unreleased（2026-10-29 `gh` 查詢；[CHANGELOG.md:3](CHANGELOG.md)）。

## 近期：可以直接動手
| 項目 | 為什麼 | 驗收方式 | 建議執行者 | 證據 |
| --- | --- | --- | --- | --- |
| 重現並修正系統匣查詢逾時 | 在等待期限前同步讀 stdout、stderr，掛住的子程序無法被期限保護 | 用不退出與塞滿 stderr 的假 CLI 重現；改為雙流安全讀取及有效期限，超時能結束子程序、回報錯誤，5.1／7 均通過相關測試 | Codex | [scripts/codex-reset-tray.ps1:122](scripts/codex-reset-tray.ps1)；深掃報告（2026-10-27）「刻意不修／觀察」 |
| 查明 Pages 失敗是否需要處理 | 快照有失敗結果，但不能推定是產品程式錯誤 | 讀最近 `Publish GitHub Pages` 失敗步驟；區分站點設定、私有 repo 方案限制與流程缺陷，只有可重現流程缺陷才修；若原因是私有 repo 方案不支援 Pages，屬已知邊界，結論是停用該 workflow 或交維護者決定；需改可見性或付費時交維護者決定 | Codex | 2026-10-29 `gh run list -w "Publish GitHub Pages"`：2026-10-17 failure；[.github/workflows/pages.yml:1](.github/workflows/pages.yml) |
| 核對修正後的 Windows 安裝與移除路徑 | 深掃只測純函式與解析，未跑真實安裝／解除安裝 | 隔離使用者環境驗證單項 PATH 不黏連、系統匣讀取摘要、無 pwsh 可回退、查詢失敗保留視窗；移除後捷徑及安裝檔清乾淨且保留其他 PATH | 維護者 | [REVIEW.md:26](REVIEW.md)、[CHANGELOG.md:7](CHANGELOG.md)；深掃報告（2026-10-27）「範圍」 |

## 中期：等條件成立再做
| 項目 | 觸發條件 | 驗收方式 | 建議執行者 | 證據 |
| --- | --- | --- | --- | --- |
| 發布包含 Windows 修正的執行檔 | 安裝與產品驗收通過，維護者授權發行 | 更新版本及 Scoop 所需資訊；重建執行檔並核對來源與雜湊，tag、Release、可下載資產一致，下載版 smoke 通過 | Codex | [AGENTS.md:78](AGENTS.md)、[CHANGELOG.md:3](CHANGELOG.md)、[tools/build_exe.ps1:50](tools/build_exe.ps1) |
| 收緊建置成功判斷 | 準備發布新版，或確認不再允許沿用舊執行檔 | 以編譯失敗／舊 exe 存在與 postject 非零案例驗證；失敗不可把舊產物標成本次成功，正常產物能執行 `--version` | Codex | [tools/build_exe.ps1:78](tools/build_exe.ps1)、[tools/build_exe.ps1:85](tools/build_exe.ps1)；深掃報告（2026-10-27）的既有取捨 |
| 重審 Ruff 延後版本 | freshness 顯示超過已審精度的新版本 | 用新版本跑 `ruff check --select E9,F tools` 與維護測試；保持下限的相容承諾，採用或續延附理由 | Codex | [docs/DECISIONS.md:52](docs/DECISIONS.md) |

## 刻意不做
| 不做什麼 | 理由 | 什麼情況下重新考慮 |
| --- | --- | --- |
| 用真帳戶執行 reset 當 smoke | reset 會消耗可用額度，查詢驗收不需要它；見 [README.md:34](README.md) | 維護者明確要求測試消耗額度的行為 |
| 引進舊 iCalendar 寫入功能 | 決策與產品邊界見 [docs/DECISIONS.md:27](docs/DECISIONS.md) | 維護者提出新的匯出需求與本機寫入規格 |
| 為 Pages 失敗直接改公開或升級付費方案 | 失敗原因與站點需求尚未確認 | 維護者確認站點用途及帳戶設定變更 |

## 維護方式
每週依 [tools/upstream_baseline.json](tools/upstream_baseline.json) 審新增差量；歷史無共同祖先時用 cherry-pick 或最小重做，不改寫歷史。每月沿用 freshness 與 Dependabot 維護依賴；發行時除了 [AGENTS.md](AGENTS.md) 的 gate，必須核對下載產物及安裝路徑，理由記 [docs/DECISIONS.md](docs/DECISIONS.md)。
