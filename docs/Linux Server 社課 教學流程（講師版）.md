# Linux Server 社課 教學流程（講師版）

Nov 16, 2026 · @lolLeo

## 課程總覽

全程約 75 分鐘，用一個「app 掛了」的故事串起五段：你是新接手的維運，要找出 app 沒在跑的原因、修好、確認恢復。

| 段 | 主題 | 時間（分） | 學員產出 |
| --- | --- | --- | --- |
| 1 | SSH 登入 | 10 | 說出自己的 whoami 與 hostname |
| 2 | SSH 金鑰登入 | 15 | 免密碼登入成功 |
| 3 | 找出問題 | 20 | `error.txt` 拉回筆電 |
| 4 | 權限與執行腳本 | 10 | `./demo.sh` 執行成功 |
| 5 | 修復與服務 | 20 | app.log 最後出現 started |

驗收點有三個：免密碼登入成功；`error.txt` 拉回筆電；`tail ~/.log/app.log` 看到 started。

簡報只放三個目標頁：公鑰登入、把錯誤報告拉回筆電、lab-app 啟動。排查的思考方式（目的 → 觀察 → 執行 → 觀察；錯誤看 log、指令查 `--help` 或 Google、環境看 docs）由講師口述，不放簡報。

時間最緊的是第 5 段，因為要先花 2 分鐘介紹 nano。需要時從第 4 段的講解借時間（`ls -l` 拆解、權限數字表可以講快一點），但 `demo.sh` 的實作要留著。

## 第 1 段：SSH 登入（10 分）

目標：每位學員成功登入，並能分辨自己現在在哪台電腦。

1. 輸入 `ssh 帳號@IP`。
2. 第一次連線會問 fingerprint，輸入 `yes`。講解：這是在確認伺服器身分，之後會記在 `known_hosts`。
3. 輸入密碼。講解：畫面不會顯示任何字元，不是當機。
4. 看提示字元 `帳號@主機名:~$`，再用 `whoami`、`hostname` 確認，並和自己筆電的提示字元對照。

講解重點：

- 「遠端」和「本機」的差別，提示字元是最快的判斷方式。
- `~` 是自己的家目錄，`$` 表示一般使用者（root 是 `#`）。

檢查點：每人能說出自己的 hostname。

## 第 2 段：SSH 金鑰登入（15 分）

目標：學員完成公鑰登入，重新登入不再輸入密碼。`scp` 在這裡第一次出現，用來上傳公鑰；第 3 段會再用它把報告下載回筆電。

1. 筆電執行 `ssh-keygen -t ed25519`，一路 Enter。講解：會產生私鑰與公鑰 `.pub`，私鑰絕不外傳。
2. 筆電執行 `scp ~/.ssh/id_ed25519.pub 帳號@IP:~/`，把公鑰傳到伺服器家目錄。
3. 伺服器執行 `mkdir -p ~/.ssh`，再 `cat ~/id_ed25519.pub >> ~/.ssh/authorized_keys`。講解：`>>` 是接到檔案最後面，真實伺服器上 `authorized_keys` 通常已經有別人的金鑰，用 `>` 會全部蓋掉。這裡只講到這樣，第 3 段再讓他們親手體驗 `>` 和 `>>` 的差別。
4. 伺服器執行 `chmod 700 ~/.ssh` 與 `chmod 600 ~/.ssh/authorized_keys`。講解：第 4 段會再回來講為什麼私密檔要 600。
5. `exit` 登出，再 `ssh 帳號@IP`，確認不用輸入密碼。

平台差異：

- Windows 請用 PowerShell，公鑰路徑是 `$env:USERPROFILE\.ssh\id_ed25519.pub`。Windows 沒有 `ssh-copy-id`，所以教手動做法。
- macOS 與 Linux 直接用終端機，路徑為 `~/.ssh/id_ed25519.pub`。

常見錯誤：重新登入仍要密碼，大多是 `authorized_keys` 拼錯、用了 `>` 蓋掉公鑰、或 `~/.ssh` 權限不對。

檢查點：免密碼登入成功。

## 第 3 段：找出問題（20 分）

目標：從一堆 log 找出 app 沒跑的原因，存成 `~/reports/error.txt`，再拉回筆電。不在這一段修復。

1. `ls` 看不到東西 → `ls -la` 找到 `.log/` 與 `.config/`。講解：`.` 開頭是隱藏檔。
2. `cd .log`、`pwd` 確認位置，`ls -lh` 看大小。
3. `cat app.log` 被洗版。講解：大檔不要直接 `cat`。
4. `less app.log`：空白鍵往下翻，`b` 往回翻，`/ERROR` 搜尋、`n` 找下一個，`G` 跳到結尾，`q` 離開。
5. `grep ERROR app.log` 列出所有錯誤。講解：`cat app.log | grep ERROR` 也能用，直接 `grep ERROR app.log` 少一步，不必糾正學員。
6. `touch ~/error.txt` 建立空檔，再 `grep ERROR app.log >> ~/error.txt`。重跑一次，`cat ~/error.txt` 會發現內容重複（`>>` 是追加，回扣第 2 段放公鑰時用的就是它）。改用 `grep ERROR app.log > ~/error.txt` 覆蓋回一份（`>` 是覆蓋）。
7. 管線：`grep ERROR app.log | tail -n 1` 只看最新一筆錯誤，`grep ERROR app.log | wc -l` 數錯誤筆數。講解：`|` 把前一個指令的輸出交給下一個。
8. 整理：`cd ~`、`mkdir reports`、`mv error.txt reports/`，再 `cp reports/error.txt reports/error.bak`，最後 `rm reports/error.bak`。提醒：`rm` 沒有垃圾桶。
9. 結論：最後一筆 ERROR 說要把 `enable` 改成 `true`，設定在 `app/config.json`，留到第 5 段修。
10. 把報告拉回筆電：先 `exit`（或筆電另開終端機），執行 `scp 帳號@IP:~/reports/error.txt .`。講解：方向和第 2 段相反，「來源 → 目的地」；這次不用密碼，證明金鑰登入有效。

檢查點：筆電上有 `error.txt`，且內容包含最後那筆 ERROR。

## 第 4 段：權限與執行腳本（10 分）

目標：學員看得懂 `ls -l` 的一行輸出，知道自己能做什麼、不能做什麼；並親手讓一個腳本從「不能執行」變成「可以執行」。前三步講解，第 4 步學員動手。

1. 使用者、群組、root：用 `id` 看自己的身分。root 是管理員，學員沒有 sudo，所以改不了系統。
2. `ls -l` 怎麼看：用自己的 `ls -l ~/.config/app/config.json` 拆解五個部分：檔案類型、擁有者權限、群組權限、其他人權限、擁有者與群組。
3. 對比：`ls -l /etc/shadow`，再 `cat /etc/shadow` 被拒絕（Permission denied）。
4. 學員動手執行預置的腳本（`~/.local/scripts/demo.sh`，setup 放好、擁有者是學員、權限 644）：
   1. `cd ~/.local/scripts`，`ls -l` 看到 `rw-r--r--`，`cat demo.sh` 看內容。講解：腳本就是把指令一行一行寫進檔案；第一行 `#!/bin/bash` 告訴系統用 bash 來跑。
   2. `./demo.sh` → `Permission denied`。講解：Linux 不看副檔名，`.sh` 不代表能執行，要看有沒有 `x`。
   3. `chmod +x demo.sh`，再 `ls -l` 看到三段都多了 `x`。
   4. `./demo.sh` → 印出「執行成功！我是 lab07…」。
   5. 對照：直接打 `demo.sh`（不加 `./`）→ `command not found`。講解：shell 只會到 `PATH` 裡的目錄找指令，目前目錄不在裡面，所以要用 `./` 指明「這個目錄下的」；`ls`、`cat` 能直接打，是因為它們在 `/usr/bin`。
   6. 補充：`bash demo.sh` 不需要 `x` 也能跑，因為執行的是 `bash`，`demo.sh` 只是被它讀進去。
5. 回到第 2 段：為什麼 `~/.ssh` 要 700、`authorized_keys` 要 600。SSH 對私密檔案的權限很嚴格。

| 權限值 | 符號 | 常見用途 |
| --- | --- | --- |
| 644 | `rw-r--r--` | 一般檔案 |
| 755 | `rwxr-xr-x` | 可執行檔與目錄 |
| 600 | `rw-------` | 私密檔案，例如 SSH 金鑰 |

記憶方式：r=4、w=2、x=1，三個數字依序是擁有者、群組、其他人。

檢查點：`./demo.sh` 印出「執行成功」（計分板「4腳本」變 ✓；只看 `~/.local/scripts/demo.sh` 的擁有者有沒有 `x`）。

## 第 5 段：修復與服務（約 20 分）

目標：用 `nano` 把 `enable` 改成 `true`，重啟服務，再用 log 確認成功。

1. 花 2 分鐘介紹 `nano`：`nano 檔名` 開啟，方向鍵移動，直接打字，Ctrl+O 存檔（Enter 確認檔名），Ctrl+X 離開。畫面下方的 `^` 就是 Ctrl。
2. 找設定檔：`ls ~/.config | grep app` 找到 `app` 目錄；或 `find ~/.config -name config.json` 找到多筆，靠路徑中的 `app` 判斷。讓學員看到兩種做法都行。
3. `cd ~/.config/app`、`cat config.json` 看到 `{"enable": false}`，先 `cp config.json config.json.bak` 備份。
4. `nano config.json`，把 `false` 改成 `true`，存檔離開。提醒：`true` 要小寫、不加引號，逗號和括號不要動。
5. `systemctl --user restart lab-app`。
6. 驗證：`tail ~/.log/app.log` 看到 `INFO: started`，再執行一次確認 heartbeat 在增加；`systemctl --user status lab-app` 顯示 active (running)。
7. 程序小實作：`sleep 1000 &` 在背景開一個程序，`ps -u $USER` 找到它的 PID，`kill <PID>`，再 `ps -u $USER` 確認消失。
8. 選做：`systemctl --user stop lab-app`，確認 log 不再增加，再 `start` 回來。講解程序和服務的差別。

學員改壞時，從 log 就能判斷：

| log 訊息 | 原因 | 修法 |
| --- | --- | --- |
| `app is disabled` | 還沒改或改錯行 | 把 `enable` 改成 `true` |
| `invalid JSON` | 少了或多了引號、逗號、括號 | `cp config.json.bak config.json` 重來 |
| `must be true or false` | 寫成 `"true"` 或 `True` | 改成小寫、不加引號的 `true` |

檢查點：`tail ~/.log/app.log` 看到 `INFO: started`。

## 指令總表與學到的觀念

全部用到的指令按類別整理，第三欄是第幾段用到。

| 類別 | 指令 | 段 |
| --- | --- | --- |
| 登入與身分 | `ssh`、`whoami`、`hostname`、`exit`、`id` | 1、2、3、4 |
| 瀏覽 | `pwd`、`ls`（`-a` `-l` `-h`）、`cd`、`find` | 3、5 |
| 讀檔 | `cat`、`less`、`tail`、`wc -l` | 2、3、5 |
| 搜尋與管線 | `grep`、`\|`、`>`、`>>` | 2、3、5 |
| 檔案管理 | `touch`、`mkdir`、`cp`、`mv`、`rm` | 2、3、5 |
| 編輯 | `nano` | 5 |
| 傳輸與金鑰 | `ssh-keygen`、`scp` | 2、3 |
| 權限與執行 | `ls -l`、`chmod`、`./腳本`、`bash 腳本` | 2、4 |
| 程序與服務 | `ps -u $USER`、`kill`、`sleep &`、`systemctl --user status`、`restart`、`stop` | 5 |

學到的觀念：

- 隱藏檔以 `.` 開頭，要 `ls -a` 才看得到。
- 大檔不要 `cat`，用 `less` 翻頁、用 `tail` 看結尾。
- `grep 關鍵字 檔案` 不需要先 `cat`。
- 管線 `|` 把前一個指令的輸出交給下一個，可以串起來過濾或計數。
- `>` 覆蓋、`>>` 追加，寫錯會有真實後果。
- 改設定前先備份，這是維運的基本習慣。
- 排錯順序：看 log 找錯誤 → 找設定檔 → 修改 → 重啟 → 再看 log 確認。
- 權限：擁有者、群組、其他人各自有 rwx，沒有 sudo 就不能碰系統。
- 檔案要有 `x` 才能執行，副檔名不算數；執行目前目錄的程式要加 `./`。
- 程序和服務不同：程序是跑一次的東西，服務由 systemd 管理，用 `systemctl` 控制。
- `--user`：每個使用者有自己的一套服務，不需要 sudo，互不影響。

## 常見問題與講師備註

| 狀況 | 處理 |
| --- | --- |
| 輸入密碼沒反應 | 不是當機，密碼不會顯示，直接打完按 Enter |
| `systemctl --user` 出現 `Failed to connect to bus` | 伺服器缺 `dbus-user-session` 或 `libpam-systemd`，或不是用一般 SSH 登入 |
| 重新登入仍要密碼 | 檢查 `authorized_keys` 拼字、是否用了 `>`、`~/.ssh` 與檔案權限 |
| 改壞 `config.json` | `cp config.json.bak config.json` 重來 |
| `./demo.sh` 出現 `Permission denied` | 這就是第 4 段要他們看到的；`ls -l` 看 `x`，`chmod +x` |
| `demo.sh: command not found` | 少了 `./` |
| `./demo.sh: No such file or directory` | 不在 `~/.local/scripts`，先 `cd ~/.local/scripts` |
| `demo.sh` 被改壞或刪掉 | root 執行 `setup.sh --reseed-user labNN` 重新產生 |
| `>` 與 `>>` 搞混 | 第 3 段就是要讓他們搞混一次，再一起看結果 |
| 學員習慣先 `cat` 再接 `grep` | 兩種都行，順口提醒直接 `grep` 少一步即可 |

講師備註：

- 時間最緊的是第 5 段，第 4 段的講解可以縮短來讓出時間，`demo.sh` 實作約 3 分鐘不要省。
- 第 2 段之前先確認每位學員的筆電有 `ssh`、`scp` 與 `ssh-keygen`。Windows 10 以上通常內建，老版本要先安裝 OpenSSH 用戶端。
- 中途卡住的人，先問他們 `tail ~/.log/app.log` 看到什麼，log 就是答案。
- 啟動與還原腳本另案處理，課前要確認每位學員的時間戳、服務狀態都回到初始值。
