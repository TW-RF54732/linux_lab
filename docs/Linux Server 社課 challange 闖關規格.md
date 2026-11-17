# Linux Server 社課 challange 闖關規格

Nov 17, 2026 · @lolLeo

## 目標與範圍

學員在 `~/challange` 解密拿到 flag。過程中 daemon「evil-killer」會吃掉解出來的 flag，學員必須用 `systemctl --user` 停掉它。

- 練到的能力：權限（x 權限、root 的唯讀檔）、檔案操作（`cp`、`>>`、`ln -s`）、服務管理（`systemctl --user status / stop`）、scp。
- 範圍內：目錄與檔案配置、密鑰、解密器、evil-killer、flag 與 bonus、`~/README.txt`、`lab` 指令、講師操作、驗收。
- 沿用《Lab 環境需求規格》：帳號 `labNN`、群組 `labusers`、學員沒有 sudo、共用程式放 `/opt/lab/`、家目錄 750、每人已 `loginctl enable-linger`、伺服器支援 `systemctl --user`。
- 課堂上只教 `systemctl --user`，**不教 `kill`**。所有提示與文件都以 `systemctl --user stop` 為標準解法。
- 目錄名稱照指定拼寫為 `challange`，所有程式、提示與文件都要用同一個拼法。

## 學員的解題流程

學員從 `~/README.txt` 得知目標與流程，README 不給指令，指令由學員自己推出來，或用 `lab hint` 取得。

1. 讀 `~/README.txt`，知道解密器在 `~/challange`、密鑰在 `/lab/key.txt`。
2. 執行解密器，出現 Permission denied → 用 `chmod +x` 補上執行權限（`bash decoder.sh` 也可以）。
3. 解密器說找不到 `~/challange/key.txt` → 把 `/lab/key.txt` 放過去，`cp`、`cat >>`、`ln -s` 都可以。
4. 解密成功，產生 `~/challange/flag.html`，約 1 秒後被吃掉，同時出現 `~/challange/evil.txt`。
5. `cat evil.txt` 得知兇手是 evil-killer → `systemctl --user status evil-killer` 確認 → `systemctl --user stop evil-killer`。
6. 再解密一次，`cat flag.html` 拿到 flag，用 `lab flag` 提交。
7. bonus：用 scp 下載 `flag.html` 回筆電，或在伺服器用 `python3 -m http.server`，用瀏覽器看到隱藏的像素字，用 `lab bonus` 提交。

## 檔案配置

| 路徑 | 擁有者 | 權限 | 初始狀態 | 用途 |
| --- | --- | --- | --- | --- |
| `/lab/` | root | 755 | 存在 | 放密鑰的共用目錄 |
| `/lab/key.txt` | root | 644 | 存在 | 密鑰，所有人可讀、不可改 |
| `~/README.txt` | labNN | 644 | 存在 | 闖關目標與流程，不含指令 |
| `~/challange/` | labNN | 755 | 存在 | 闖關目錄 |
| `~/challange/decoder.sh` | labNN | **444** | 存在 | 解密器，刻意沒有 x |
| `~/challange/key.txt` | — | — | **不存在** | 學員要自己放進來 |
| `~/challange/flag.html` | labNN | 644 | **不存在** | 解密器產生 |
| `~/challange/evil.txt` | labNN | 644 | **不存在** | flag 第一次被吃掉後由 evil-killer 產生 |
| `/opt/lab/evil-killer` | root | 755 | 存在 | daemon 本體 |
| `/etc/systemd/user/evil-killer.service` | root | 644 | 存在 | user service 定義 |

`decoder.sh` 的擁有者是學員本人，學員才能自己 `chmod +x`。

## 密鑰

全班共用一把密鑰，放在 `/lab/key.txt`；每位學員的 flag 不同，因為各自的加密內容不同。

- 長度 128 字元，用安全亂數產生（例如 Python `secrets`）。
- 字元集：大小寫英文、數字，加上 `!@#$%^&*()-_=+[];:,.<>?/~`。
- 字元集**排除**空白、引號、反斜線、`{`、`}`。排除大括號是為了確保密鑰本身不會含有 flag 標記 `flag{`，否則學員放到家目錄的 key.txt 會被 evil-killer 吃掉。
- 檔案只有一行，就是密鑰本身加換行。
- 長度與亂度的目的：讓手打或用滑鼠選取都不實際，逼學員用指令搬。
- 硬連結 `ln /lab/key.txt ...` 會失敗（跨檔案系統，或核心的 `protected_hardlinks` 擋下），這是預期行為；符號連結 `ln -s` 可以用。

## 解密器 decoder.sh

bash 腳本，加密後的 `flag.html` 以 base64 內嵌在腳本裡，每位學員一份。

| 項目 | 規格 |
| --- | --- |
| 讀取密鑰 | `~/challange/key.txt` 的**第一行**，路徑寫死 |
| 輸出 | `~/challange/flag.html`，路徑寫死 |
| 加密方式 | `openssl enc -aes-256-cbc -pbkdf2`，`-pass file:` 指向 key.txt |
| 成功判斷 | openssl 成功，且輸出內容含 flag 標記 |
| 寫檔方式 | 先寫到暫存檔，驗證通過才 `mv` 到 flag.html；失敗不留下任何檔案 |

輸出訊息（固定文字，方便學員看訊息自己修正）：

| 狀況 | 訊息 |
| --- | --- |
| key.txt 不存在 | `[錯誤] 找不到密鑰檔：~/challange/key.txt`，並說明「密鑰放在哪裡請看 ~/README.txt，檔名要一模一樣」 |
| key.txt 讀不到（權限不足或符號連結斷掉） | `[錯誤] 讀不到密鑰檔` |
| 密鑰錯誤 | `[錯誤] 密鑰不正確`，並說明「key.txt 的第一行必須完全等於密鑰」 |
| 成功 | `[成功] 已解密到 ~/challange/flag.html` |

注意：解密器原始碼**不可以出現字串 `flag{`**，否則會被 evil-killer 當成 flag 吃掉（實測發生過）。驗證輸出時用 `grep -q 'flag[{]'` 這類寫法。

## evil-killer

以學員本人身分執行的 user service，每 1 秒執行一輪。

**吃檔規則**：檔案內容含 `flag{` 就刪除，只看內容，不看檔名。

| 範圍 | 條件 |
| --- | --- |
| `~` 底下全部（遞迴） | 一般檔案，內容含 `flag{` |
| `/tmp`、`/dev/shm` | 深度 ≤ 3、擁有者是學員本人、小於 1 MB、內容含 `flag{` |

排除項目：`~/.lab/`（lab 指令存的答案）、`~/.bash_history`（學員打過 `lab flag '...'`）。

**evil.txt 規則**：

- 初始不存在；第一次吃掉 flag 之後才出現在 `~/challange/evil.txt`。
- 內容固定一份，寫入後不會改變（不分階段）。
- evil-killer 還在跑時：被刪會在 1 秒內重新出現，被改會在 1 秒內蓋回原內容。
- evil-killer 停止後：檔案保持原樣，學員可以自由刪除，刪了不會再出現。
- 內容：自製 ASCII 臉（不可使用現成角色），下面接三行固定文字：

```
I am evil-killer
I eat your flag hahaha
try to stop me!!
```

**服務定義**（`/etc/systemd/user/evil-killer.service`）：

```
[Unit]
Description=evil-killer
ConditionGroup=labusers

[Service]
ExecStart=/opt/lab/evil-killer
Restart=no

[Install]
WantedBy=default.target
```

- 程序名稱固定為 `evil-killer`，講師端用 `pgrep -u labNN -x evil-killer` 判斷存活。
- 不做 `systemctl --global enable`，闖關開始時才由講師啟動（見「講師操作」）。
- `Restart=no`：學員若自己用 `kill` 也停得掉，這是可接受的非標準解，不另外防堵也不教。
- 等待用 `sleep 1 &` 加 `wait`，收到 TERM 能立即結束，`systemctl --user stop` 不會卡住。

**停止後的預期結果**：

| 學員的做法 | 結果 |
| --- | --- |
| `systemctl --user stop evil-killer` | 服務 inactive，不再吃檔；evil.txt 可刪除 |
| `systemctl --user disable evil-killer` | 仍在執行，沒用（可當收尾講解：stop 與 disable 的差別） |
| 刪除 evil.txt | 1 秒後重新出現 |

## flag.html 與 bonus

一個 HTML 檔：用 cat 看得到 flag，bonus 只有用瀏覽器打開才看得到。

- flag 格式：`flag{evil_is_dead_<8 位 hex>}`，每位學員不同。
- 頁面上的文字：`<h1>flag is: flag{...}</h1>`、一行「用 lab flag 提交」、一行「bonus 用 cat 看不到」、`<h1>bonus</h1>`。
- bonus：5 個字元，每位學員不同，字元集 `ACDEFHJKLMNPRTUWXY34679`（排除容易看錯的字）。
- bonus 畫法：一個元素的 CSS `box-shadow` 列出每個像素點的座標，用 5×7 點陣字畫出來，座標順序打亂。cat 只會看到一長串數字。
- 學員看 bonus 的兩種方法：
  - scp：`scp labNN@IP:~/challange/flag.html .`，在筆電用瀏覽器打開。
  - http.server：在 `~/challange` 執行 `python3 -m http.server <port>`，從筆電瀏覽器連進來。每人一個 port（建議 8100 + 學員編號），防火牆要開放這段 port。
- 提醒學員 http.server 要在 `~/challange` 裡執行，它會公開執行位置整個資料夾的檔案。

## ~/README.txt

說明目標與流程，**不出現任何指令**。建議全文如下，可微調文字：

```
================ challange ================
學長留了一份加密的檔案給你，解開就能拿到 flag。
但這台 server 上住著一隻搗蛋鬼，牠會吃掉你解出來的東西。

目標
  拿到 flag，用 lab 提交。
  隱藏目標：flag 檔裡還藏了一個 bonus，只有「畫出來」才看得到。

你手上有
  解密器：~/challange/decoder.sh
  密鑰：  /lab/key.txt   （所有人都能讀，但不能改）

流程
  1. 讓解密器可以執行
  2. 把密鑰放到解密器要的位置（解密器會告訴你在哪）
  3. 執行解密器
  4. flag 不見了？找出是誰幹的，讓牠停下來
  5. 再解密一次，拿到 flag

規則
  不准用滑鼠複製貼上密鑰，用指令搞定它。
  卡住了：lab hint
============================================
```

## lab 指令

`/usr/local/bin/lab`，學員不需要 sudo 就能執行。

| 指令 | 誰用 | 功能 |
| --- | --- | --- |
| `lab` | 學員 | 顯示任務摘要，以及 evil-killer 是否在跑、flag 與 bonus 是否已取得 |
| `lab hint` / `lab hint N` | 學員 | 逐步提示，共 5 個，提示可以給指令 |
| `lab flag '<flag>'` | 學員 | 提交 flag |
| `lab bonus <文字>` | 學員 | 提交 bonus，不分大小寫 |
| `sudo lab --start` | 講師 | 對每位學員執行 `systemctl --user enable --now evil-killer` |
| `sudo lab --stop` | 講師 | 對每位學員執行 `systemctl --user disable --now evil-killer` |
| `sudo lab --all` | 講師 | 計分板：每人的 evil-killer 狀態、flag、bonus |

- 答案檢查：只存「加鹽的 sha256」，放在 `/var/lib/lab/users/labNN.json`（644）。學員看得到也推不回答案。明文答案另存 root 專用目錄。
- 學員提交正確的值存到 `~/.lab/flag`、`~/.lab/bonus`，計分板讀取並重新比對雜湊。
- 講師端對學員下 user 指令的方式：`runuser -u labNN -- env XDG_RUNTIME_DIR=/run/user/<uid> systemctl --user ...`。
- 提示內容（依序）：
  1. 先讀 `~/README.txt`，然後執行解密器
  2. Permission denied：`ls -l` 看 x 權限，用 `chmod +x`
  3. 找不到密鑰：密鑰在 `/lab/key.txt`，用 `cp`、`cat >>` 或 `ln -s` 放到解密器要的位置
  4. flag 不見了：看 `evil.txt`，用 `systemctl --user status evil-killer`、`systemctl --user stop evil-killer`
  5. 提交與 bonus：`lab flag '...'`；bonus 用 scp 或 http.server 在瀏覽器看
- 提示只用 `systemctl --user`，不出現 `kill`、`ps`。

## 講師操作

| 時間點 | 指令 |
| --- | --- |
| 建置 | 由建置腳本產生密鑰、每人的 decoder、README、答案雜湊 |
| 闖關開始 | `sudo lab --start` |
| 上課中 | `sudo watch -c -n 5 env LAB_COLOR=1 lab --all` 投影計分板 |
| 下課 | `sudo lab --stop` |
| 重置單一學員 | 刪掉 `~/challange` 內產生的檔案、重新產生 decoder，並重啟該學員的 evil-killer |

## 開課前驗證清單

用一個測試帳號，從學員網段的筆電依序確認：

- [ ] `ls -l /lab/key.txt` 為 root 644，學員可 `cat`，不可修改或刪除
- [ ] 密鑰長度 128，且 `grep -F '{' /lab/key.txt` 無結果
- [ ] `~/challange` 只有 `decoder.sh`（444），沒有 `evil.txt`、`key.txt`、`flag.html`
- [ ] `grep -rF 'flag{' ~` 無結果（任何預置檔都不能含標記）
- [ ] `./decoder.sh` 出現 Permission denied；`chmod +x` 後可執行；`bash decoder.sh` 也能執行
- [ ] 未放密鑰時錯誤訊息正確；分別用 `cp`、`cat >>`、`ln -s` 放密鑰都能解密
- [ ] key.txt 第一行不是密鑰時（例如先寫了別的再 `>>`），顯示密鑰不正確，且不留下 flag.html
- [ ] `sudo lab --start` 後，`systemctl --user status evil-killer` 為 active
- [ ] 解密後 1 秒內 flag.html 消失，`evil.txt` 出現且內容正確
- [ ] 刪除或修改 evil.txt，1 秒內恢復原內容
- [ ] 把 flag 內容 `cp` 到 `/tmp` 或家目錄其他位置，同樣被吃
- [ ] `~/.lab/` 與 `.bash_history` 沒被吃
- [ ] `systemctl --user stop evil-killer` 立即生效；之後刪 evil.txt 不再出現；再解密 flag.html 保留
- [ ] `lab flag`、`lab bonus` 對錯判斷正確，計分板同步更新
- [ ] 筆電 scp 下載 flag.html，瀏覽器看得到 bonus；http.server 從筆電連得到
- [ ] 另一個學員帳號無法影響測試帳號的 evil-killer 與檔案
- [ ] `sudo lab --stop` 後所有人的 evil-killer 都停止
