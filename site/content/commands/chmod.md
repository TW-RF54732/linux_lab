---
title: chmod
summary: 修改權限
description: 修改檔案或目錄的權限。可以用數字（600）或符號（+x）兩種寫法。
---

## 常用 {#basics}

```command
chmod 600 ~/.ssh/authorized_keys
```

| 寫法 | 做什麼 |
| --- | --- |
| `chmod 644 檔案` | 一般檔案 |
| `chmod 600 檔案` | 只有自己能讀寫 |
| `chmod 755 檔案` | 自己全部，其他人可讀可執行 |
| `chmod 700 目錄` | 只有自己能進入 |
| `chmod +x 檔案` | 加上執行權限 |

數字的意思見 [檔案權限](/commands/permissions/)。只有檔案的擁有者能改權限。

## 進階 {#advanced}

符號寫法：`對象` + `操作` + `權限`。

| 部分 | 可以寫 |
| --- | --- |
| 對象 | `u` 擁有者、`g` 群組、`o` 其他人、`a` 全部 |
| 操作 | `+` 加上、`-` 拿掉、`=` 設成剛好這樣 |
| 權限 | `r`、`w`、`x` |

| 例子 | 做什麼 |
| --- | --- |
| `chmod u+x 檔案` | 只有自己加上執行 |
| `chmod go-r 檔案` | 群組與其他人拿掉讀取 |
| `chmod -R 700 目錄` | 目錄和裡面所有東西一起改 |
| `chmod -v 644 檔案` | 顯示改了什麼 |

## 範例 {#examples}

```command
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

第 2 段：設定 SSH 要求的權限。

```command
cd ~/.local/scripts
./demo.sh
chmod +x demo.sh
ls -l demo.sh
./demo.sh
```

```output
-bash: ./demo.sh: Permission denied
-rwxr-xr-x 1 lab07 lab07 306 Nov 19 09:12 demo.sh
執行成功！我是 lab07，在 linux-lab 上
腳本就是把指令一行一行寫進檔案，加上 x 就能當成程式執行
```

第 4 段：預先放好的腳本沒有 `x`，執行被拒；`chmod +x` 之後三段都多了 `x`，就能用 `./demo.sh` 執行。完整步驟見 [課程任務地圖](/guide/lab-tasks/#part-4)。

## 常見錯誤 {#errors}

| 訊息 | 原因 | 怎麼辦 |
| --- | --- | --- |
| `./demo.sh: Permission denied` | 檔案沒有 `x` | `ls -l` 確認，`chmod +x demo.sh`；或改用 `bash demo.sh`（不需要 `x`） |
| `demo.sh: command not found` | 少了 `./`，shell 只到 `PATH` 裡的目錄找指令 | 改打 `./demo.sh` |
| `./demo.sh: No such file or directory` | 目前目錄下沒有這個檔案 | `pwd`、`ls` 確認自己在哪；第 4 段的腳本在 `~/.local/scripts` |
| `./xxx.sh` 沒有任何輸出 | 檔案是空的（例如用 `touch` 建的） | `cat` 看內容 |
| `Operation not permitted` | 想改別人的檔案，只有擁有者能改權限 | `ls -l` 看擁有者 |
