# Linux Server 社課 Lab 環境需求規格

Nov 16, 2026 · @lolLeo

## 目標與範圍

這個 lab 讓零基礎學員在自己的 Linux 帳號中，走完一輪排錯：讀 log、找到錯誤、改設定、重啟服務、驗證結果。

- 範圍內：伺服器環境、學員帳號、預置檔案、daemon 與 systemd user service、SSH 與資源限制。
- 範圍外：每堂課前後的啟動與還原腳本（另案）、學員筆電的環境準備。
- 設計原則：學員沒有 sudo；學員會操作的內容都放在自己的家目錄 `~` 之下。
- 開放問題：學員人數 N，以及伺服器發行版。本文暫以 Ubuntu 24.04 LTS 為準。

## 伺服器與系統需求

伺服器需支援 systemd user service，負載很輕：每位學員只跑一個小 daemon，設備以實測為準。

| 項目 | 需求 | 備註 |
| --- | --- | --- |
| 作業系統 | Ubuntu 24.04 LTS（或 22.04、Debian 12） | 需 systemd，且支援 `systemctl --user` |
| 資源（估計） | 2 vCPU、4 GB RAM、10 GB 磁磟 | 適用 N ≤ 30，上課前實測調整 |
| 套件 | `openssh-server`、`libpam-systemd`、`dbus-user-session`、`nano`、`less`、`grep`、`findutils`、`procps` | 前三項缺一會造成 `systemctl --user` 連不上 bus |
| daemon 執行環境 | `bash` 或 `python3`（擇一） | 需能解析 JSON；用 bash 則需 `jq` |
| 網路 | 學員網段可連 TCP 22 | 教室共用一個對外 IP 時要留意 SSH 防護規則 |
| 時鐘 | 啟用 NTP | log 的時間戳要合理 |

## 帳號與目錄規劃

每位學員一個獨立 Linux 帳號，沒有 sudo，學員會動到的檔案都在 `~` 之下。

- 帳號命名：`lab01` 到 `labNN`，字元組固定編號，方便點名與還原。
- 登入 shell：`/bin/bash`。不加入 `sudo`、`adm` 等特權群組，使用各自的私人群組。
- 密碼：每人一組，由腳本產生並印成名單；是否強制首次改密碼待決定（建議不強制，避免干擾課程）。
- 共用程式例外：daemon 程式本體放在 `/opt/lab/`，學員只讀不改。這是對「都在 `~`」的刻意例外，目的是避免每人一份。

| 路徑 | 擁有者 | 權限 | 用途 |
| --- | --- | --- | --- |
| `/home/labNN` | labNN | 750 | 學員家目錄，其他學員無法進入 |
| `~/.log/` | labNN | 755 | 預置 log，學員可讀寫 |
| `~/.config/` | labNN | 755 | 預置設定，學員可讀寫 |
| `/opt/lab/lab-app` | root | 755 | daemon 程式本體 |
| `/etc/systemd/user/lab-app.service` | root | 644 | 全域 user service 定義 |

## SSH 設定

密碼登入和公鑰登入都要能用，且要能承受全班同時登入。

| 設定 | 值 | 原因 |
| --- | --- | --- |
| `PasswordAuthentication` | `yes` | 第 1 段用密碼登入 |
| `PubkeyAuthentication` | `yes` | 第 3 段公鑰登入 |
| `PermitRootLogin` | `no` | 避免 root 被嘗試 |
| `AllowGroups` | `labusers` | 只允許學員與管理者登入 |
| `MaxStartups` | 調高，例如 `50:30:100` | 預設值在多人同時連線時可能拒絕部分連線，上課前實測 |

其他注意事項：

- 公鑰登入會檢查權限：`~/.ssh` 的群組與其他人不可寫，家目錄也不可被其他人寫入。`authorized_keys` 用 `>>` 建立的 644 可以直接使用。
- `~/.ssh` 不預建，讓學員在第 3 段自己 `mkdir -p`。
- 若安裝了 fail2ban，教室共用同一個對外 IP，打錯密碼可能連坐整間教室，需把教室網段加入白名單或暫停。

## 預置檔案

每位學員的家目錄內容相同，由固定種子產生，還原時可重現。所有檔案擁有者都是該學員，因為 daemon 以學員身分寫 log。

| 路徑 | 內容 | 用途 |
| --- | --- | --- |
| `~/.log/app.log` | 約 2000 行，以 INFO 和 WARN 為主，夠雜數筆已解決的舊 ERROR；最後一筆是 `ERROR: app is disabled, set "enable" to true in app/config.json` | 第 2 段找錯誤，第 5 段驗證 |
| `~/.log/` 其他 log | `access.log`、`db.log`、`cron.log`、`boot.log`，各數百到數千行雜訊，不含與本題相關的 ERROR | 讓 `ls -lh` 有東西可看，體驗「要挑對檔」 |
| `~/.config/app/config.json` | `{"enable": false}` | 第 5 段要修的設定檔 |
| `~/.config/` 其他目錄 | 至少 5 個無關程式的目錄，其中至少 2 個也有 `config.json` | 讓 `find ~/.config -name config.json` 有多筆結果，靠路徑判斷 |

其他要求：

- `app.log` 的時間戳要和開課當天接近，最後一筆錯誤是「剛剛才發生」的樣子。
- 家目錄其他地方保持空白，不預建 `~/.ssh`、`~/reports`、`~/error.txt`。

## lab-app daemon 與 user service

daemon 讀 `~/.config/app/config.json`，把結果寫到 `~/.log/app.log`；設定錯就寫明確的 ERROR 並結束，讓學員看 log 就能自己修。

log 格式：`YYYY-MM-DD HH:MM:SS LEVEL: message`，以追加方式寫入。

| 狀況 | log 輸出 | 結束碼 |
| --- | --- | --- |
| `enable` 為 `false` | `ERROR: app is disabled, set "enable" to true in app/config.json` | 78 |
| JSON 格式壞掉 | `ERROR: invalid JSON in app/config.json (line N)` | 78 |
| `enable` 不是布林值（例如 `"true"`） | `ERROR: "enable" must be true or false (boolean)` | 78 |
| 檔案不存在 | `ERROR: app/config.json not found` | 78 |
| `enable` 為 `true` | `INFO: started`，之後每 5 秒 `INFO: heartbeat` | 持續執行 |

user service 設定：

- 定義檔：`/etc/systemd/user/lab-app.service`，`Type=simple`、`ExecStart=/opt/lab/lab-app`，`Restart=no`。不自動重啟，這樣失敗狀態才看得到，也不會刷出大量 log。
- 啟用方式：`systemctl --global enable lab-app.service`，一份定義所有學員共用。
- 每位學員執行 `loginctl enable-linger labNN`，讓 user 服務管理器不依賴登入也存在。
- 初始狀態：服務為 failed，且 `app.log` 最後一筆是上表第一列的 ERROR。這由啟動與還原腳本保證，另案處理。

## 資源限制與安全

目的是讓一位學員的失誤不會影響其他人或整台伺服器。下表數值為建議起點，上課前實測。

| 項目 | 設定 | 說明 |
| --- | --- | --- |
| 每人程序數上限 | `TasksMax=200` | 寫在 `/etc/systemd/system/user-.slice.d/lab.conf` 的 `[Slice]`，防 fork bomb |
| 每人記憶體上限 | `MemoryMax=512M` | 同上檔案 |
| 家目錄權限 | 750 | 學員互相看不到對方的檔案 |
| sudo | 不走 `sudo`、`adm` 群組 | 確認 `sudo -l` 被拒 |
| 磁磟配額 | 選配，例如每人 100 MB | 防止有人把磁磟寫滿 |
| `/proc` 隱藏其他人程序 | 選配，`hidepid=2` | 目前流程不需要看別人的程序，可以不開 |

學員互相可見的部分：`ps aux` 看得到別人的程序，但 `kill` 會被拒絕。這是 Linux 權限的正常行為，不需要額外處理。

## 開課前驗證清單

用一個測試帳號，從學員網段的外部電腦依序確認：

- [ ] 用密碼 SSH 登入成功
- [ ] `id` 不含 sudo 與 adm，`sudo -l` 被拒
- [ ] `ls -a ~` 有 `.log`、`.config`，且沒有 `.ssh`、`reports`、`error.txt`
- [ ] `systemctl --user status lab-app` 可執行，沒有 `Failed to connect to bus`
- [ ] 服務狀態為 failed，`tail ~/.log/app.log` 最後一筆是 `app is disabled`
- [ ] 改成 `true` 後 `restart`，`app.log` 出現 `started`，且 heartbeat 持續增加
- [ ] 故意改壞 JSON、改成 `"true"` 字串，各自出現對應的明確 ERROR
- [ ] Windows PowerShell 與 macOS 各測一次手動公鑰流程，免密碼登入成功
- [ ] N 人同時登入沒有被 `MaxStartups` 或 fail2ban 擋下
- [ ] 在測試帳號跑 fork 超過 `TasksMax`，只影響自己，其他帳號正常
- [ ] 還原腳本能把測試帳號回到初始狀態（另案，等腳本完成後檢查）
