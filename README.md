# Linux Server 社課 Lab 環境

依「Linux Server 社課 Lab 環境需求規格」在 **Proxmox 的 Ubuntu 24.04 CT（LXC）** 裡部署整套 lab：
學員帳號、預置 log 與設定檔、`lab-app` daemon 與 systemd user service、SSH 設定、每人資源限制，
以及依「Linux Server 社課 challange 闖關規格」做的 challange 闖關（evil-killer）與 `lab` 進度／計分板指令。

範圍外（另案）：每堂課前後的啟動與還原腳本。不過 `setup.sh --reseed` 已能把所有學員的預置檔與服務狀態重新產生到初始值，可以當還原腳本的基礎。

## 檔案

| 檔案 | 用途 | 部署位置 |
| --- | --- | --- |
| `lab.conf.example` → `lab.conf`（不進 git） | 人數 N、帳號前綴、管理者、時區、種子、資源上限 | — |
| `setup.sh` | 在 CT 內以 root 部署整套環境，可重複執行 | — |
| `verify.sh` | 在 CT 內跑開課前驗證清單中能自動化的部分 | — |
| `proxmox/create-ct.sh` | 在 Proxmox 主機建 CT、推檔案、執行 `setup.sh` | — |
| `files/lab-app` | daemon（Python 3，只用標準函式庫） | `/opt/lab/lab-app`（root 755） |
| `files/lab-app.service` | user service 定義 | `/etc/systemd/user/lab-app.service`（root 644） |
| `files/lab-seed` | 產生學員家目錄預置檔（固定種子） | `/opt/lab/admin/lab-seed`（root 700） |
| `files/evil-killer` | challange 的搗蛋 daemon（bash） | `/opt/lab/evil-killer`（root 755） |
| `files/evil-killer.service` | user service 定義（不做 global enable） | `/etc/systemd/user/evil-killer.service`（root 644） |
| `files/lab-challange` | 產生密鑰、每位學員的 decoder／README／答案（Python 3） | `/opt/lab/admin/lab-challange`（root 700） |
| `files/lab` | 學員看進度／提示／提交，講師計分板與 evil-killer 開關（Python 3） | `/usr/local/bin/lab`（root 755） |

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

2. 把目錄放進 CT（例如 `/root/linux_lab`），先 `cp lab.conf.example lab.conf` 並修改 `lab.conf`，再以 root 執行：

   ```bash
   bash /root/linux_lab/setup.sh
   ```

部署完成後，密碼名單在 CT 內的 `/root/lab-roster.csv`（root 600，CSV：`account,password`）。

### 部署前要決定的設定（`lab.conf`）

- `LAB_COUNT`：學員人數 N，帳號為 `lab01`…`labNN`。
- `LAB_ADMINS`：管理者帳號（要先存在，例如 `adduser leo`）。**root 不能 SSH**，留空的話只能用 `pct enter <CTID>` 管理。
- `LAB_TZ`：log 時間戳的時區，預設 `Asia/Taipei`。

## setup.sh 做了什麼

1. 安裝 `openssh-server libpam-systemd dbus-user-session nano less grep findutils procps python3 sudo openssl`，設定時區。
2. 建立群組：`labusers`（學員）與 `labadmins`（管理者）。
3. 安裝 `/opt/lab/lab-app` 與 `/etc/systemd/user/lab-app.service`，並 `systemctl --global enable`。
4. 寫 `/etc/systemd/system/user-.slice.d/lab.conf`：`TasksMax=200`、`MemoryMax=512M`。
5. 寫 `/etc/ssh/sshd_config.d/00-lab.conf`，用 `sshd -t` 與 `sshd -T` 確認有效設定後才重啟 sshd。
6. 建立 `labNN` 帳號：`/bin/bash`、私人群組 + `labusers`、不在 `sudo`/`adm`、家目錄 750、隨機密碼（不強制首次改密碼）。
   預建 `~/.ssh`（700）與空的 `~/.ssh/authorized_keys`（600）；已存在的不清空，只修正擁有者與權限。
7. 對每個新帳號建立初始狀態：
   - `loginctl enable-linger`
   - 用 `lab-seed` 產生 `~/.log/*.log` 與 `~/.config/*`（app.log 先不含最後一筆 ERROR）
   - 真的啟動一次 `lab-app`，讓它自己寫出 `ERROR: app is disabled …` 並以 78 結束
   - 確認服務為 **failed**、`app.log` 最後一筆是該 ERROR

   - 寫入教學檢查點的基準時間 `/var/lib/lab/lesson/labNN`（`lab --all` 只看這之後的登入與下載紀錄）

   已有預置檔的帳號會略過；加 `--reseed` 會全部重新產生；只想還原某幾個帳號用 `--reseed-user lab05`（可重複指定）。
8. challange：安裝 `evil-killer`、`lab`、`lab-challange`，產生 `/lab/key.txt`（已存在就只檢查格式）；
   寫入並啟動 `/etc/systemd/system/lab-progress.service`（學員端進度快取）；
   每位學員產生 `~/.challange/README.txt`、`~/.challange/decoder.sh`（444）與答案。evil-killer 先停著。
   已產生過的會略過；`--reseed` 會停掉 evil-killer 並全部重產（新的 flag 與 bonus）。

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
| 闖關目錄 | `~/challange`，README 在 `~/README.txt` | `~/.challange/`，README 在 `~/.challange/README.txt` | 隱藏目錄，教學第 3 段「`ls` 看不到東西」不受影響；入口改由 `lab`（不帶參數）與 `lab hint 1` 告訴學員先讀 README |
| 答案雜湊 | 加鹽 sha256，`labNN.json` 644 | pbkdf2-sha256（200k 次）、`root:labNN` 640 | 644 時別人讀得到；8 位 hex 與 5 字 bonus 用單次 sha256 很快就暴力破解得出來 |
| 計分板比對 | 讀 `~/.lab` 重新比對雜湊 | 和 root 專用的明文答案比對 | 每 5 秒刷新 30 人，不必每次算 pbkdf2 |
| 重置單一學員 | 手動步驟 | `sudo lab --reset labNN` | 一個指令做完：停 evil-killer、重產 decoder 與答案、原本在跑就重新啟動 |
| `lab hint` | 逐步提示 | 不加 N 時依目前進度自動挑一則 | 學員不用自己判斷該看第幾則 |
| 投影計分板 | `sudo watch -c -n 5 env LAB_COLOR=1 lab --all` | `sudo lab --watch` | `watch` 在非 UTF-8 locale 下會吃掉所有中文字 |
| `lab` 指令 | 只有 challange | 學員端與計分板都加上教學第 1、2、3、5 段的檢查點 | 講師在 root 一眼看出誰落後 |
| sshd | — | 加 `ExposeAuthInfo yes`、`Subsystem sftp internal-sftp -l INFO` | 學員端判斷這次是否用金鑰登入；計分板從 sftp 紀錄判斷 error.txt 有沒有被拉回筆電。舊版 OpenSSH 不接受重複的 `Subsystem` 時 setup 會自動拿掉這行 |
| evil-killer 排除 | `~/.lab/`、`~/.bash_history` | 只排除家目錄頂層這兩個路徑 | 避免學員把 flag 藏在任意名為 `.lab` 的子目錄 |
| `~/.ssh` | 不預建，學員第 2 段自己 `mkdir -p` | setup 預建 `~/.ssh`（700）與空的 `authorized_keys`（600） | 學員只要把公鑰 `>>` 進去，不會卡在權限；`mkdir -p` 照樣不會出錯。計分板把空的 `authorized_keys` 視為還沒放公鑰 |

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
- 預設也會檢查 challange 初始狀態：`/lab/key.txt`、`~/.challange` 只有 `README.txt` 與 `decoder.sh`（444）、家目錄沒有 flag 標記、`./decoder.sh` 是 Permission denied、evil-killer 沒在跑、答案檔權限。
- `--challange`：完整跑一次闖關（`lab --start`、三種放密鑰方式、被吃、evil.txt 恢復、`/tmp` 規則、`disable` 沒用、`stop`、提交 flag/bonus、`lab --all` 同步），最後 `lab --reset` 還原。**結尾會跑一次 `lab --stop`（所有學員）**，請在課前執行。
- `--progress`：用臨時金鑰 `ssh` 與 `sftp` 到測試帳號，確認計分板的第 1、2、3 段偵測，最後把 `authorized_keys` 清回空檔、刪掉 `~/report`。之後計分板會一直顯示測試帳號已完成，開課前 `setup.sh --reseed` 重設基準時間。
- `--user lab05`：改用別的帳號（建議另外留一個測試帳號）。

需要從**學員網段的外部電腦**手動確認的項目：

- [ ] 用密碼 `ssh lab01@<IP>` 登入成功，提示字元是 `lab01@<hostname>:~$`
- [ ] `systemctl --user status lab-app` 沒有 `Failed to connect to bus`（真正經過 SSH 登入的 PAM session）
- [ ] Windows PowerShell 與 macOS 各跑一次第 2 段手動公鑰流程，重新登入不用密碼
- [ ] N 人同時登入沒有被 `MaxStartups` 擋下
- [ ] 還原腳本能把測試帳號回到初始狀態（另案）
- [ ] 筆電 `scp labNN@<IP>:~/.challange/flag.html .` 下載後用瀏覽器看得到 bonus
- [ ] 伺服器在 `~/.challange` 跑 `python3 -m http.server 81NN`，筆電瀏覽器連得到（Proxmox 防火牆要開 8101–81NN）
- [ ] Windows 與 macOS 各用 `scp` 拉一次 `error.txt`，計分板第 3 段變 ✓（Windows 10 內建的舊版 scp 走 legacy 協定不留紀錄，只會到 △）

## challange 闖關與 `lab` 指令

| 時間點 | 指令 |
| --- | --- |
| 建置 | `setup.sh`（`--reseed` 會全部重產） |
| 闖關開始 | `sudo lab --start` |
| 上課中 | `sudo lab --watch` 投影計分板（每 5 秒更新；`lab --watch 3` 改間隔） |
| 下課 | `sudo lab --stop` |
| 重置單一學員 | `sudo lab --reset labNN` |

`--start`、`--stop` 後面可以接帳號，只對那幾位操作。不要用 `watch lab --all` 投影：Ubuntu CT 預設 locale 不是 UTF-8，`watch` 走 ncurses 會把中文與 ✓△ 全部吃掉，`lab --watch` 自己重畫畫面，不受影響。`lab --all --json` 輸出機器可讀的狀態（`verify.sh` 用）。

計分板每人一列，`✓` 完成、`△` 做一半、`✗` 有問題、`·` 還沒做，最後一列是每欄完成人數，「備註」顯示第一個沒完成的教學項目卡在哪：

| 欄 | 判斷方式 |
| --- | --- |
| 在線 | 有屬於該學員的 `sshd` 程序 |
| 1 登入 | 基準時間後 journal 有 `Accepted … for labNN`，或目前在線 |
| 2 金鑰 | ✓ journal 有 `Accepted publickey`；△ `authorized_keys` 放好了但還沒用金鑰登入；✗ 沒有金鑰行或權限太寬 |
| 3 報告 | ✓ sftp 紀錄有讀取 `error.txt`（拉回筆電）；△ `~/report/error.txt` 或 `~/reports/error.txt` 做好了（兩個目錄名都認），或 `~/error.txt` 還沒搬 |
| 5 服務 | ✓ setup 寫的那筆 `app is disabled` 之後出現過 `INFO: started`；✗ 之後最後一筆 ERROR 的類別 |
| 鑰 / 吃 / 停 | `~/.challange/key.txt` 第一行等於密鑰 / `evil.txt` 出現過 / `evil.txt` 在且 evil-killer 已停 |
| flag / bonus | `~/.lab/flag`、`~/.lab/bonus` 和答案相同 |
| evil | evil-killer 正在跑 |

學員端 `lab` 顯示同樣的教學檢查點與 challange 狀態。學員讀不到 sshd 的 journal，所以由 root 常駐的 `lab-progress.service`（`lab --refresh --loop 5`）每 5 秒把每人的登入／金鑰登入／下載紀錄寫成 `/var/lib/lab/progress/labNN.json`（`root:labNN` 640），學員端讀這份快取；`setup.sh --reseed` 換了基準時間後，舊快取會被忽略。

## 開課當天

時間戳以「產生的時間」為準。開課前重新產生一次，讓最後一筆 ERROR 看起來是剛剛才發生：

```bash
/root/linux_lab/setup.sh --reseed
```

注意 `--reseed`／`--reseed-user` 只重新產生 `~/.log`、`~/.config`、服務狀態與 `~/.challange`（含 `~/.lab`），**不會**清空學員上一堂課放進 `~/.ssh/authorized_keys` 的公鑰（`verify.sh` 會提醒），也不會刪掉 `~/report`（或 `~/reports`）、`~/error.txt` 等檔案；完整還原屬於另案的還原腳本。
