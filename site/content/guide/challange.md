---
title: challange 闖關
nav: challange 闖關
summary: 解開加密檔拿到 flag，同時對付會吃檔案的搗蛋鬼
description: 學長留了一份加密的檔案給你，解開就能拿到 flag。但伺服器上住著一隻搗蛋鬼，會吃掉你解出來的東西。整關會用到權限、檔案操作、服務管理和 scp。
---

## 目標 {#story}

| 目標 | 怎麼算完成 |
| --- | --- |
| flag | 解開 `~/.challange` 裡的加密檔，用 `lab flag` 提交 |
| bonus（隱藏目標） | flag 檔裡還藏了 5 個字，只有「畫出來」才看得到，用 `lab bonus` 提交 |

闖關由講師宣布開始。開始之後 `lab` 會顯示 `evil-killer：執行中`。

這一頁只講規則和怎麼看懂訊息，**不給完整解法**。卡住的時候用 [lab hint](/commands/lab/#hints)，或點下面的連結查指令怎麼用。

## 開始 {#start}

```command
lab
cat ~/.challange/README.txt
```

`.challange` 以 `.` 開頭，是隱藏目錄，`ls` 看不到，要 `ls -a`。README 寫了流程，但**不會告訴你指令**：

1. 讓解密器可以執行
2. 把密鑰放到解密器要的位置（解密器會告訴你在哪）
3. 執行解密器
4. flag 不見了？找出是誰幹的，讓牠停下來
5. 再解密一次，拿到 flag

### 規則 {#rules}

- 密鑰有 128 個字元，**不准用滑鼠複製貼上**，用指令搬。
- 只能動自己家目錄裡的東西。`/lab/key.txt` 所有人都能讀，但不能改。

## 你手上的東西 {#files}

| 路徑 | 權限 | 說明 |
| --- | --- | --- |
| `~/.challange/README.txt` | `rw-r--r--` | 闖關說明 |
| `~/.challange/decoder.sh` | `r--r--r--` | 解密器，加密的 flag 檔就藏在裡面。擁有者是你 |
| `/lab/key.txt` | `rw-r--r--`，擁有者 root | 密鑰，全班共用同一把 |

過程中會出現的檔案：

| 路徑 | 什麼時候出現 |
| --- | --- |
| `~/.challange/key.txt` | 你自己放進去 |
| `~/.challange/flag.html` | 解密成功後產生 |
| `~/.challange/evil.txt` | flag 第一次不見之後 |

每個人的 flag 和 bonus 都不一樣，抄同學的答案不會過。

## 解密器的訊息 {#decoder}

解密器的每個錯誤都會說清楚哪裡不對：

| 看到 | 意思 | 查哪裡 |
| --- | --- | --- |
| `Permission denied` | 檔案沒有執行權限 `x` | [檔案權限](/commands/permissions/)、[chmod](/commands/chmod/) |
| `[錯誤] 找不到密鑰檔：~/.challange/key.txt` | 密鑰還沒放到這個位置，或檔名不一樣 | [cp](/commands/cp/)、[重新導向 >>](/commands/redirection/)、[ln](/commands/ln/) |
| `[錯誤] 讀不到密鑰檔` | `key.txt` 沒有讀取權限，或是斷掉的連結 | [ln：常見錯誤](/commands/ln/#errors) |
| `[錯誤] 密鑰不正確` | `key.txt` 的**第一行**不是密鑰 | 見下方 |
| `[成功] 已解密到 ~/.challange/flag.html` | 解開了 | — |

> [!WARNING]
> 解密器只看 `key.txt` 的**第一行**。用 `>>` 接到一個已經有內容的檔案後面，密鑰會跑到第二行以後，就會「密鑰不正確」。用 `cat ~/.challange/key.txt` 檢查，不對就 `rm` 掉重來。

## flag 不見了 {#eaten}

解密成功，可是一下子 `flag.html` 就不見了：伺服器上有東西在吃含有 flag 的檔案。

- 看看 `~/.challange` 裡多了什麼，`cat` 它。
- 它是一個**服務**，和 `lab-app` 一樣由 systemd 管理，是你自己帳號底下的服務。
- 把 flag 複製到家目錄別的地方或 `/tmp` 躲不掉，要讓它停下來。

讓服務停下來的方法見 [systemd 使用者服務](/environment/systemd-user/) 與 [systemctl](/commands/systemctl/)，注意 [stop 和 disable 的差別](/commands/systemctl/#stop-vs-disable)。停下來之後再執行一次解密器。

## 提交 {#submit}

```command
cat ~/.challange/flag.html
```

在輸出裡找到 flag（`flag` 開頭、大括號包起來的一串字），整串用單引號包起來提交：

```reference
lab flag '整串 flag'
```

細節見 [lab：提交](/commands/lab/#submit)。

## bonus {#bonus}

`cat` 看到的只有一長串數字，bonus 是用 CSS 一個點一個點畫出來的，要用**瀏覽器**打開 `flag.html` 才看得到。兩種方法擇一：

### 方法一：拉回筆電 {#bonus-scp}

在**筆電**執行，和第 3 段把 `error.txt` 拉回來一樣：

```command
scp 帳號@IP:~/.challange/flag.html .
```

再用瀏覽器打開筆電上的 `flag.html`。

### 方法二：在伺服器開網頁 {#bonus-http}

在**伺服器**執行，port 是 `8100 + 你的編號`，例如 `lab07` 用 `8107`：

```command
cd ~/.challange
python3 -m http.server 8107
```

筆電瀏覽器開 `http://IP:8107/flag.html`。看完回到終端機按 [[Ctrl+C]] 關掉。

> [!WARNING]
> `http.server` 會把**執行時所在的目錄**整個公開給任何人看。一定要先 `cd ~/.challange`，不要在家目錄執行。

看到的 5 個字用 `lab bonus` 提交，大小寫都可以。

## 卡住時 {#stuck}

| 狀況 | 先看 |
| --- | --- |
| 不知道下一步 | `lab hint`，會依進度給提示 |
| `ls` 找不到 `.challange` | 用 `ls -a` |
| 解密器報錯 | [解密器的訊息](#decoder) |
| `systemctl --user` 出現 `Failed to connect to bus` | [systemd 使用者服務：疑難排解](/environment/systemd-user/#troubleshooting) |
| 提交說不對 | [lab：常見錯誤](/commands/lab/#errors) |
| 瀏覽器打不開 `http://IP:port` | port 打錯，或伺服器那邊的 `http.server` 已經關掉；改用方法一 |
