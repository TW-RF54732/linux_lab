---
title: 管線與導向：| > >>
nav: | > >>（管線與導向）
summary: | 把結果交給下一個指令，> 覆蓋寫入檔案，>> 追加到檔案
description: 指令的結果預設印在畫面上。用 | 交給下一個指令繼續處理，用 > 或 >> 存到檔案。
---

## 常用 {#basics}

```command
grep ERROR app.log | tail -n 1
grep ERROR app.log > ~/error.txt
grep ERROR app.log >> ~/error.txt
```

| 符號 | 名稱 | 做什麼 | 記法 |
| --- | --- | --- | --- |
| `\|` | 管線 | 把左邊指令的結果，交給右邊的指令 | 像水管把兩個指令接起來 |
| `>` | 覆蓋 | 把結果寫進檔案，**原本的內容會被清掉** | 一個箭頭，砍掉重寫 |
| `>>` | 追加 | 把結果加到檔案最後面，原本的內容保留 | 兩個箭頭，往後接 |

檔案不存在時，`>` 和 `>>` 都會自動建立。

## 管線 | {#pipe}

```command
grep ERROR app.log | tail -n 1
grep ERROR app.log | wc -l
ls ~/.config | grep app
```

1. 找出所有 ERROR → 只留最後一筆。
2. 找出所有 ERROR → 數有幾行。
3. 列出目錄 → 只留含有 `app` 的。

可以一直串下去，每一段只做一件事：

```command
grep ERROR app.log | grep -v database | wc -l
```

找 ERROR → 排除含 database 的 → 計數。

## 覆蓋 > 與追加 >> {#overwrite-append}

差一個字元，結果差很多。實際做一次：

```command
grep ERROR app.log >> ~/error.txt
grep ERROR app.log >> ~/error.txt
wc -l ~/error.txt
```

```output
16 /home/lab07/error.txt
```

`>>` 跑兩次，內容重複了。改用 `>`：

```command
grep ERROR app.log > ~/error.txt
wc -l ~/error.txt
```

```output
8 /home/lab07/error.txt
```

回到只有一份。

> [!WARNING]
> `>` 會直接清掉原本的內容，**沒辦法復原**。
>
> 第 2 段把公鑰加進 `authorized_keys` 一定要用 `>>`：
> `cat ~/id_ed25519.pub >> ~/.ssh/authorized_keys`
> 用 `>` 會把裡面原有的其他公鑰全部蓋掉。

## 進階 {#advanced}

| 寫法 | 做什麼 |
| --- | --- |
| `2> 檔案` | 只把**錯誤訊息**寫進檔案 |
| `2>/dev/null` | 丟掉錯誤訊息，`/dev/null` 是會吃掉一切的特殊檔案 |
| `> 檔案 2>&1` | 正常結果和錯誤訊息都寫進同一個檔案 |
| `< 檔案` | 從檔案讀入，而不是從鍵盤 |
| `指令 \| tee 檔案` | 畫面上看得到，同時存進檔案；`tee -a` 是追加 |

為什麼要分開處理錯誤訊息？例如在整台機器搜尋時，會出現一堆 `Permission denied`：

```command
find / -name sshd_config 2>/dev/null
```

加上 `2>/dev/null` 就只剩下真正找到的結果。

> [!NOTE]
> `|` 只會傳遞正常結果，錯誤訊息還是會直接印在畫面上。

## 範例 {#examples}

```command
grep ERROR app.log | tail -n 1
grep -c WARN app.log
grep ERROR app.log > ~/error.txt
echo '{"enable": false}' > ~/.config/app/config.json
ls -l ~/.log | tee ~/reports/logs.txt
```

1. 最新一筆錯誤。
2. 不用管線也能數，`grep -c` 直接計數。
3. 把錯誤存成報告。
4. 用 `>` 把設定檔寫回初始內容。
5. 一邊看一邊存。
