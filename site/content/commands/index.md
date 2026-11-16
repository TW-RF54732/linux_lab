---
title: 指令參考
nav: 指令總表
summary: 全部指令依類別整理
description: 課堂用到的所有指令。每一頁都先講常用寫法，再講進階選項與範例。
---

## 常用 {#basics}

| 類別 | 指令 | 用途 |
| --- | --- | --- |
| 登入與身分 | [ssh](/commands/ssh/) | 遠端登入伺服器 |
| | [whoami](/commands/whoami/) | 我是誰 |
| | [hostname](/commands/hostname/) | 這台電腦叫什麼 |
| | [id](/commands/id/) | 我屬於哪些群組 |
| | [exit](/commands/exit/) | 登出 |
| 瀏覽 | [pwd](/commands/pwd/) | 我在哪個目錄 |
| | [ls](/commands/ls/) | 列出檔案 |
| | [cd](/commands/cd/) | 切換目錄 |
| | [find](/commands/find/) | 依名稱找檔案 |
| 讀檔 | [cat](/commands/cat/) | 印出整個檔案 |
| | [less](/commands/less/) | 分頁看大檔案 |
| | [tail](/commands/tail/) | 看檔案最後幾行 |
| | [wc](/commands/wc/) | 數行數 |
| 搜尋與管線 | [grep](/commands/grep/) | 找出含有關鍵字的行 |
| | [`\|` `>` `>>`](/commands/redirection/) | 交給下一個指令、覆蓋寫入、追加寫入 |
| 檔案管理 | [touch](/commands/touch/) | 建立空檔案 |
| | [mkdir](/commands/mkdir/) | 建立目錄 |
| | [cp](/commands/cp/) | 複製 |
| | [mv](/commands/mv/) | 移動或改名 |
| | [rm](/commands/rm/) | 刪除 |
| 編輯 | [nano](/commands/nano/) | 文字編輯器 |
| 傳輸與金鑰 | [ssh-keygen](/commands/ssh-keygen/) | 產生 SSH 金鑰 |
| | [scp](/commands/scp/) | 在電腦之間傳檔案 |
| 權限 | [檔案權限](/commands/permissions/) | 看懂 `rwx` 與 `644` |
| | [chmod](/commands/chmod/) | 修改權限 |
| 程序與服務 | [ps](/commands/ps/) | 列出程序 |
| | [kill](/commands/kill/) | 結束程序 |
| | [sleep](/commands/sleep/) | 等待一段時間 |
| | [背景執行](/commands/jobs/) | `&`、`jobs`、`fg` |
| | [systemctl](/commands/systemctl/) | 管理服務 |

## 三個一定要會的符號 {#symbols}

| 符號 | 做什麼 | 例子 |
| --- | --- | --- |
| `\|` | 把結果交給下一個指令 | `grep ERROR app.log \| wc -l` |
| `>` | 寫進檔案，**清掉原本的內容** | `grep ERROR app.log > error.txt` |
| `>>` | 加到檔案最後面 | `cat key.pub >> authorized_keys` |

詳細說明見 [| > >>](/commands/redirection/)。

## 查更多 {#more}

這裡只列常用的選項。想知道全部，用 `指令 --help` 或 `man 指令`，見 [如何查指令](/guide/reading-docs/)。
