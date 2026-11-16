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
| 2 | 找出問題 | `~/reports/error.txt` |
| 3 | SSH 金鑰登入 | 免密碼登入成功 |
| 4 | 權限（講解） | 看懂 `ls -l` 的一行輸出 |
| 5 | 修復與服務 | `~/.log/app.log` 最後出現 `INFO: started` |

驗收三件事：`~/reports/error.txt` 存在；重新登入不用密碼；`tail ~/.log/app.log` 看到 `started`。

下面的 `帳號` 與 `IP` 換成講師發給你的值，例如 `lab07` 與 `192.168.10.50`。

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

## 第 2 段：找出問題 {#part-2}

```command
ls
ls -la
cd .log
pwd
ls -lh
```

`ls` 什麼都沒有，`ls -la` 才看到以 `.` 開頭的隱藏目錄 `.log` 與 `.config`。`app.log` 很大，不要 `cat`，改用 `less` 翻頁，或用 `grep` 直接過濾：

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

文件：[ls](/commands/ls/)、[cd](/commands/cd/)、[pwd](/commands/pwd/)、[less](/commands/less/)、[grep](/commands/grep/)、[| > >>](/commands/redirection/)、[tail](/commands/tail/)、[wc](/commands/wc/)、[touch](/commands/touch/)、[mkdir](/commands/mkdir/)、[mv](/commands/mv/)、[cp](/commands/cp/)、[rm](/commands/rm/)、[家目錄與預置檔案](/environment/home/)。

## 第 3 段：SSH 金鑰登入 {#part-3}

在**筆電**產生金鑰並把公鑰傳上去（一路按 [[Enter]]）：

```command
ssh-keygen -t ed25519
scp ~/.ssh/id_ed25519.pub 帳號@IP:~/
```

Windows PowerShell 的公鑰路徑是 `$env:USERPROFILE\.ssh\id_ed25519.pub`。

在**伺服器**把公鑰加進 `authorized_keys`，並設定權限：

```command
mkdir -p ~/.ssh
cat ~/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
exit
```

再 `ssh 帳號@IP` 一次，應該不用輸入密碼。

文件：[ssh-keygen](/commands/ssh-keygen/)、[scp](/commands/scp/)、[chmod](/commands/chmod/)、[SSH 伺服器的金鑰登入條件](/environment/sshd/#pubkey)。

## 第 4 段：權限 {#part-4}

```command
id
ls -l ~/.config/app/config.json
ls -l /etc/shadow
cat /etc/shadow
```

最後一行會得到 `Permission denied`：你不是 root，也沒有 sudo。示範 `chmod +x`：

```command
touch demo.sh
ls -l demo.sh
chmod +x demo.sh
ls -l demo.sh
```

文件：[檔案權限](/commands/permissions/)、[id](/commands/id/)、[chmod](/commands/chmod/)。

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

## 卡住時 {#stuck}

| 狀況 | 先看 |
| --- | --- |
| 輸入密碼沒反應 | 正常，密碼不會顯示，打完按 [[Enter]] |
| `Failed to connect to bus` | [systemd 使用者服務：疑難排解](/environment/systemd-user/#troubleshooting) |
| 重新登入仍要密碼 | [SSH 伺服器：金鑰登入失敗](/environment/sshd/#pubkey) |
| 改完 config 還是沒起來 | `tail ~/.log/app.log`，對照 [lab-app 錯誤訊息](/environment/lab-app/#errors) |
| 改壞 `config.json` | `cp config.json.bak config.json` 重來 |
