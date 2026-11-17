# Linux Server 社課 Lab 環境

依「Linux Server 社課 Lab 環境需求規格」在 **Proxmox 的 Ubuntu 24.04 CT（LXC）** 裡部署整套 lab：
學員帳號、預置 log 與設定檔、`lab-app` daemon 與 systemd user service、SSH 設定、每人資源限制。

範圍外（另案）：每堂課前後的啟動與還原腳本。不過 `setup.sh --reseed` 已能把所有學員的預置檔與服務狀態重新產生到初始值，可以當還原腳本的基礎。

## 檔案

| 檔案 | 用途 | 部署位置 |
| --- | --- | --- |
| `lab.conf` | 人數 N、帳號前綴、管理者、時區、種子、資源上限 | — |
| `setup.sh` | 在 CT 內以 root 部署整套環境，可重複執行 | — |
| `verify.sh` | 在 CT 內跑開課前驗證清單中能自動化的部分 | — |
| `proxmox/create-ct.sh` | 在 Proxmox 主機建 CT、推檔案、執行 `setup.sh` | — |
| `files/lab-app` | daemon（Python 3，只用標準函式庫） | `/opt/lab/lab-app`（root 755） |
| `files/lab-app.service` | user service 定義 | `/etc/systemd/user/lab-app.service`（root 644） |
| `files/lab-seed` | 產生學員家目錄預置檔（固定種子） | `/opt/lab/admin/lab-seed`（root 700） |

## 文件網站（GitHub Pages）

給學員看的完整文件（指令與全部參數、lab 環境、`lab-app` 服務）放在 `site/`，用 `scripts/build-site.mjs` 產生靜態網站到 `dist/`，不需要 npm 套件。寫作語法見 `site/README.md`。

```bash
npm run preview:site
```

發佈：push 到 GitHub 後，在 repository 的 **Settings → Pages** 把 **Source** 設為 **GitHub Actions**。之後每次 `main` 上的 `site/` 有變動，`.github/workflows/pages.yml` 會自動建置並部署；PR 只建置與檢查連結，不部署。站內連結都是相對路徑，`https://<帳號>.github.io/<repo>/` 與自訂網域都能直接用；只有 `404.html` 需要知道路徑，部署在 `/<repo>/` 底下時把 `site/site.json` 的 `base` 改成 `"/<repo>/"`。

## 部署

### 方法一：在 Proxmox 主機一鍵建立

把整個目錄複製到 Proxmox 主機，然後：

```bash
CTID=240 IP=192.168.10.50/24 GW=192.168.10.1 ./proxmox/create-ct.sh
```

可用的環境變數：`CTID`（必填）、`IP`（預設 dhcp）、`GW`、`BRIDGE`（vmbr0）、`STORAGE`（local-lvm）、`CORES`（2）、`MEMORY`（4096）、`DISK_GB`（10）、`HOSTNAME_`（linux-lab）。
會自動下載 Ubuntu 24.04 template、建立 **unprivileged + `nesting=1`** 的 CT、推檔案、執行 `setup.sh`。

### 方法二：CT 已經建好

1. 在 Proxmox 主機確認 CT 有開 nesting（沒開的話開完要重開 CT）：

   ```bash
   pct set <CTID> --features nesting=1
   ```

2. 把目錄放進 CT（例如 `/root/linux_lab`），先改 `lab.conf`，再以 root 執行：

   ```bash
   bash /root/linux_lab/setup.sh
   ```

部署完成後，密碼名單在 CT 內的 `/root/lab-roster.csv`（root 600，CSV：`account,password`）。

### 部署前要決定的設定（`lab.conf`）

- `LAB_COUNT`：學員人數 N，帳號為 `lab01`…`labNN`。
- `LAB_ADMINS`：管理者帳號（要先存在，例如 `adduser leo`）。**root 不能 SSH**，留空的話只能用 `pct enter <CTID>` 管理。
- `LAB_TZ`：log 時間戳的時區，預設 `Asia/Taipei`。

## setup.sh 做了什麼

1. 安裝 `openssh-server libpam-systemd dbus-user-session nano less grep findutils procps python3 sudo`，設定時區。
2. 建立群組：`labusers`（學員）與 `labadmins`（管理者）。
3. 安裝 `/opt/lab/lab-app` 與 `/etc/systemd/user/lab-app.service`，並 `systemctl --global enable`。
4. 寫 `/etc/systemd/system/user-.slice.d/lab.conf`：`TasksMax=200`、`MemoryMax=512M`。
5. 寫 `/etc/ssh/sshd_config.d/00-lab.conf`，用 `sshd -t` 與 `sshd -T` 確認有效設定後才重啟 sshd。
6. 建立 `labNN` 帳號：`/bin/bash`、私人群組 + `labusers`、不在 `sudo`/`adm`、家目錄 750、隨機密碼（不強制首次改密碼）。
7. 對每個新帳號建立初始狀態：
   - `loginctl enable-linger`
   - 用 `lab-seed` 產生 `~/.log/*.log` 與 `~/.config/*`（app.log 先不含最後一筆 ERROR）
   - 真的啟動一次 `lab-app`，讓它自己寫出 `ERROR: app is disabled …` 並以 78 結束
   - 確認服務為 **failed**、`app.log` 最後一筆是該 ERROR

   已有預置檔的帳號會略過；加 `--reseed` 會全部重新產生；只想還原某幾個帳號用 `--reseed-user lab05`（可重複指定）。

## 和規格不同或補充的地方

| 項目 | 規格 | 實作 | 原因 |
| --- | --- | --- | --- |
| `AllowGroups` | `labusers` | `labusers labadmins` | 管理者不放進 `labusers`，否則管理者的 user manager 也會跑 `lab-app`。service 用 `ConditionGroup=labusers` 只在學員身上執行 |
| daemon 停止 | 未規定 | `stop` 時寫 `INFO: stopped` | 第 5 段選做「stop 後 log 不再增加」時比較好觀察 |
| `True`、`yes` 等未加引號的字 | 嚴格來說是 JSON 語法錯誤 | 回報 `"enable" must be true or false (boolean)` | 與講師版第 5 段的表一致，對學員比較有用 |
| JSON 錯誤行號 | `line N` | 錯在檔尾（少右括號）時指向最後一行有內容的行 | 單行檔案不會出現「line 2」 |
| `~/.config` 其他目錄 | ≥5 個、≥2 個有 `config.json` | 7 個，3 個有 `config.json`（其中 `chat-bot` 也是 `"enable": false`） | 逼學員看路徑判斷；目錄名都不含 `app`，`ls ~/.config \| grep app` 只有一筆 |
| root SSH | `PermitRootLogin no`，root 不能 SSH | `lab.conf` 的 `LAB_ROOT_SSH=1` 時改為 `prohibit-password`（僅金鑰），並把 root 加進 `labadmins`；設 0 則回到規格 | 講師用金鑰直接 `ssh root@CT` 管理；密碼登入 root 仍然不行 |
| 其他 log | 不含相關 ERROR | 完全不含大寫 `ERROR` | `grep -r ERROR ~/.log` 時只會指向 app.log |

app.log 內容：約 1970 行、時間跨 3 天到開課當下，7 筆已解決的舊 ERROR（每筆後面有恢復訊息），最後一筆是 `app is disabled`。同一個 `LAB_SEED` 產生的內容完全相同，只有時間戳跟著產生時間平移。

## Proxmox CT / LXC 注意事項

- **`nesting=1` 一定要開**。Ubuntu 24.04 的 systemd 255 在沒有 nesting 的 unprivileged CT 裡，logind 與 `user@.service` 起不來，學員會看到 `Failed to connect to bus`。
- **時鐘**：CT 沒辦法自己跑 NTP（`systemd-timesyncd` 在容器內會略過），時間來自 Proxmox 主機。請確認主機的 `chrony` 正常。
- **資源限制**：Proxmox 的 CT 使用 cgroup v2，`pids` 與 `memory` controller 會委派給 CT，`user-.slice.d` 的限制可以生效。`verify.sh` 會直接讀 `/sys/fs/cgroup/.../pids.max` 確認核心真的套用了。整台 CT 的上限由 Proxmox 的 CT 記憶體設定控制，這是第二層保護。
- **磁碟配額（選配）**：CT 內無法對 rootfs 開 quota。需要的話，在 CT 設定的磁碟大小就是整體上限；真的要每人配額，要在主機端另外處理（例如每人一個 ZFS dataset）。建議先不做。
- **`hidepid=2`（選配）**：LXC 的 `/proc` 由 lxcfs 與 AppArmor 管，CT 內 remount `/proc` 通常會被拒。流程不需要，不做。
- **防火牆**：CT 內不裝 fail2ban。若有開 Proxmox 防火牆，記得讓學員網段可連 TCP 22。
- **管理者切成學員測試**：不要用 `su lab01`，`systemctl --user` 會出現 `Failed to connect to bus: Permission denied`（`XDG_RUNTIME_DIR` 還指向 root 的 `/run/user/0`）。請用 `ssh lab01@localhost`，或在 `su - lab01` 之後執行 `export XDG_RUNTIME_DIR=/run/user/$(id -u)`。

## 驗證

在 CT 內以 root 執行：

```bash
/root/linux_lab/verify.sh
```

```bash
/root/linux_lab/verify.sh --scenarios --fork-test
```

- 不加參數：檢查 `lab01` 的帳號權限、家目錄內容、服務狀態（failed + app is disabled）、SSH 有效設定、cgroup 限制。
- `--scenarios`：實際跑第 5 段（改 `true` → started + heartbeat → stop、壞 JSON、`"true"`、`True`、檔案不存在、結束碼 78），最後把 config 還原並讓服務回到 failed。**會在 app.log 多留測試行**，跑完要用 `setup.sh --reseed` 重新產生。
- `--fork-test`：在測試帳號開超過 `TasksMax` 個程序，確認被擋下、另一個帳號不受影響。
- `--user lab05`：改用別的帳號（建議另外留一個測試帳號）。

需要從**學員網段的外部電腦**手動確認的項目：

- [ ] 用密碼 `ssh lab01@<IP>` 登入成功，提示字元是 `lab01@<hostname>:~$`
- [ ] `systemctl --user status lab-app` 沒有 `Failed to connect to bus`（真正經過 SSH 登入的 PAM session）
- [ ] Windows PowerShell 與 macOS 各跑一次第 3 段手動公鑰流程，重新登入不用密碼
- [ ] N 人同時登入沒有被 `MaxStartups` 擋下
- [ ] 還原腳本能把測試帳號回到初始狀態（另案）

## 開課當天

時間戳以「產生的時間」為準。開課前重新產生一次，讓最後一筆 ERROR 看起來是剛剛才發生：

```bash
/root/linux_lab/setup.sh --reseed
```

注意 `--reseed`／`--reseed-user` 只重新產生 `~/.log`、`~/.config` 與服務狀態，**不會**刪掉學員上一堂課留下的 `~/.ssh`、`~/reports`、`~/error.txt` 等檔案；完整還原屬於另案的還原腳本。
