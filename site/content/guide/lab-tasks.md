---
title: 課程任務地圖
nav: 課程任務地圖
summary: 五段課程的步驟，每一步連到對應的文件
description: 整堂課的五個段落、每一步要打的指令，以及要回頭查文件時該點哪一頁。
---

## 故事與驗收 {#story}

你是新接手的維運。伺服器上的 `lab-app` 沒在跑，你要找出原因、修好、確認恢復。整堂課約 75 分鐘，分成五段：

| 段 | 主題 | 你的產出 |
| --- | --- | --- |
| 1 | SSH 登入 | 說出自己的 `whoami` 與 `hostname` |
| 2 | SSH 金鑰登入 | 免密碼登入成功 |
| 3 | 找出問題 | 筆電上有一份 `error.txt` |
| 4 | 權限與執行腳本 | `./demo.sh` 印出「執行成功」 |
| 5 | 修復與服務 | `~/.log/app.log` 最後出現 `INFO: started` |

驗收三件事：重新登入不用密碼；錯誤報告 `error.txt` 已經拉回筆電；`tail ~/.log/app.log` 看到 `started`。

下面的 `帳號` 與 `IP` 換成講師發給你的值，例如 `lab07` 與 `192.168.10.50`。

> [!TIP]
> 登入後隨時打 `lab`，就能看到自己每一段完成了沒、還差什麼，見 [lab 指令](/commands/lab/)。

## 第 1 段：SSH 登入 {#part-1}

在自己的筆電打開終端機（Windows 用 PowerShell）：

```command
ssh 帳號@IP
```

第一次連線會問伺服器的 fingerprint，輸入 `yes`。接著輸入密碼，畫面不會顯示任何字元，打完按 [[Enter]]。登入後確認自己在哪裡：

```command
whoami
hostname
```

提示字元會從筆電的樣子變成 `lab07@linux-lab:~$`。`~` 是家目錄，`$` 表示一般使用者。

文件：[ssh](/commands/ssh/)、[whoami](/commands/whoami/)、[hostname](/commands/hostname/)、[SSH 伺服器](/environment/sshd/#fingerprint)。

## 第 2 段：SSH 金鑰登入 {#part-2}

在**筆電**產生金鑰並把公鑰傳上去（一路按 [[Enter]]）：

```command
ssh-keygen -t ed25519
scp ~/.ssh/id_ed25519.pub 帳號@IP:~/
```

Windows PowerShell 的公鑰路徑是 `$env:USERPROFILE\.ssh\id_ed25519.pub`。

在**伺服器**把公鑰加進 `authorized_keys`，並設定權限：

`>>` 是把內容**接到檔案最後面**，原本的金鑰不會被蓋掉。第 3 段會再看它和 `>` 的差別。

```command
mkdir -p ~/.ssh
cat ~/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
exit
```

再 `ssh 帳號@IP` 一次，應該不用輸入密碼。

文件：[ssh-keygen](/commands/ssh-keygen/)、[scp](/commands/scp/)、[chmod](/commands/chmod/)、[SSH 伺服器的金鑰登入條件](/environment/sshd/#pubkey)。

## 第 3 段：找出問題 {#part-3}

```command
ls
ls -la
cd .log
pwd
ls -lh
```

`ls` 什麼都沒有，`ls -la` 才看到以 `.` 開頭的隱藏目錄 `.log` 與 `.config`（`.local` 第 4 段才用，`.challange` 是課後闖關用的，先不管它們）。`app.log` 很大，不要 `cat`，改用 `less` 翻頁，或用 `grep` 直接過濾：

```command
less app.log
grep ERROR app.log
```

在 `less` 裡用 `/ERROR` 搜尋、[[n]] 找下一個、[[G]] 跳到結尾、[[q]] 離開。

把錯誤存起來，體會 `>>`（追加）與 `>`（覆蓋）的差別：

```command
touch ~/error.txt
grep ERROR app.log >> ~/error.txt
grep ERROR app.log >> ~/error.txt
cat ~/error.txt
grep ERROR app.log > ~/error.txt
```

用管線 `|` 只看最新一筆、數總筆數：

```command
grep ERROR app.log | tail -n 1
grep ERROR app.log | wc -l
```

整理檔案：

```command
cd ~
mkdir reports
mv error.txt reports/
cp reports/error.txt reports/error.bak
rm reports/error.bak
```

結論：最後一筆 ERROR 寫著要把 `enable` 改成 `true`，設定在 `app/config.json`。留到第 5 段修。

把報告拉回**筆電**（先 `exit`，或在筆電另開一個終端機）：

```command
scp 帳號@IP:~/reports/error.txt .
```

第 2 段已經設好金鑰，這次不用輸入密碼。`.` 代表筆電上目前所在的目錄。

文件：[ls](/commands/ls/)、[cd](/commands/cd/)、[pwd](/commands/pwd/)、[less](/commands/less/)、[grep](/commands/grep/)、[| > >>](/commands/redirection/)、[tail](/commands/tail/)、[wc](/commands/wc/)、[touch](/commands/touch/)、[mkdir](/commands/mkdir/)、[mv](/commands/mv/)、[cp](/commands/cp/)、[rm](/commands/rm/)、[scp](/commands/scp/#basics)、[家目錄與預置檔案](/environment/home/)。

## 第 4 段：權限與執行腳本 {#part-4}

```command
id
ls -l ~/.config/app/config.json
ls -l /etc/shadow
cat /etc/shadow
```

最後一行會得到 `Permission denied`：你不是 root，也沒有 sudo。

接著練習執行腳本。講師已經在 `~/.local/scripts` 放好一個 `demo.sh`，先看看它：

```command
cd ~/.local/scripts
ls -l
cat demo.sh
```

```output
-rw-r--r-- 1 lab07 lab07 306 Nov 19 09:12 demo.sh
```

腳本就是把指令一行一行寫進檔案。第一行 `#!/bin/bash` 告訴系統用 bash 來跑。執行看看：

```command
./demo.sh
```

```output
-bash: ./demo.sh: Permission denied
```

權限是 `rw-r--r--`，三段都沒有 `x`，所以不能執行。Linux 不看副檔名，叫 `.sh` 不代表能跑。檔案的擁有者是你，自己就能補上執行權限：

```command
chmod +x demo.sh
ls -l
./demo.sh
```

```output
-rwxr-xr-x 1 lab07 lab07 306 Nov 19 09:12 demo.sh
執行成功！我是 lab07，在 linux-lab 上
腳本就是把指令一行一行寫進檔案，加上 x 就能當成程式執行
```

最後試試不加 `./`：

```command
demo.sh
```

```output
demo.sh: command not found
```

shell 只會去 `PATH` 裡的目錄（例如 `/usr/bin`）找指令，目前目錄不在裡面，所以執行目前目錄下的程式要寫 `./`。另外 `bash demo.sh` 不需要 `x` 也能跑：真正被執行的是 `bash`，`demo.sh` 只是被它讀進去。

文件：[檔案權限](/commands/permissions/)、[id](/commands/id/)、[chmod](/commands/chmod/#errors)、[家目錄與預置檔案](/environment/home/)。

## 第 5 段：修復與服務 {#part-5}

找到設定檔（兩種方法都可以），先備份再改：

```command
ls ~/.config | grep app
find ~/.config -name config.json
cd ~/.config/app
cat config.json
cp config.json config.json.bak
nano config.json
```

在 `nano` 裡把 `false` 改成 `true`（小寫、不加引號），[[Ctrl+O]] 存檔、[[Enter]] 確認檔名、[[Ctrl+X]] 離開。接著重啟服務並驗證：

```command
systemctl --user restart lab-app
tail ~/.log/app.log
systemctl --user status lab-app
```

看到 `INFO: started`，過幾秒再 `tail` 一次，`INFO: heartbeat` 會持續增加。

程序小實作：

```command
sleep 1000 &
ps -u $USER
kill <PID>
ps -u $USER
```

`<PID>` 換成 `ps` 輸出中 `sleep` 那一行的數字。

文件：[find](/commands/find/)、[nano](/commands/nano/)、[systemctl](/commands/systemctl/)、[lab-app 服務](/environment/lab-app/)、[sleep](/commands/sleep/)、[背景執行](/commands/jobs/)、[ps](/commands/ps/)、[kill](/commands/kill/)。

## 課後：challange 闖關 {#challange}

五段都完成後，講師會宣布開始闖關：解開加密檔拿到 flag，同時想辦法對付會吃掉 flag 的搗蛋鬼。會用到這堂課的權限、檔案操作、服務管理和 `scp`。

規則與流程見 [challange 闖關](/guide/challange/)，卡住時打 `lab hint`。

## 卡住時 {#stuck}

| 狀況 | 先看 |
| --- | --- |
| 輸入密碼沒反應 | 正常，密碼不會顯示，打完按 [[Enter]] |
| `Failed to connect to bus` | [systemd 使用者服務：疑難排解](/environment/systemd-user/#troubleshooting) |
| 重新登入仍要密碼 | [SSH 伺服器：金鑰登入失敗](/environment/sshd/#pubkey) |
| `./demo.sh` 沒反應或 `command not found` | [chmod：常見錯誤](/commands/chmod/#errors) |
| 改完 config 還是沒起來 | `tail ~/.log/app.log`，對照 [lab-app 錯誤訊息](/environment/lab-app/#errors) |
| 改壞 `config.json` | `cp config.json.bak config.json` 重來 |
| 不確定自己做完了沒 | 打 `lab`，見 [看懂進度](/commands/lab/#status) |
