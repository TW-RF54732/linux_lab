---
title: rm
summary: 刪除
description: 刪除檔案或目錄。命令列沒有垃圾桶，刪掉就救不回來。
---

## 常用 {#basics}

```command
rm reports/error.bak
```

| 寫法 | 做什麼 |
| --- | --- |
| `rm 檔案` | 刪除檔案 |
| `rm -i 檔案` | 刪除前詢問 |
| `rm -r 目錄` | 刪除目錄和裡面的所有東西 |

> [!WARNING]
> `rm` 刪掉的東西**無法復原**。用到 `*` 時，先用 `ls` 確認會刪到哪些檔案再刪。

## 進階 {#advanced}

| 選項 | 做什麼 |
| --- | --- |
| `-f` | 不詢問，檔案不存在也不報錯 |
| `-v` | 顯示刪了什麼 |
| `-d` | 刪除空目錄 |
| `--` | 刪除以 `-` 開頭的檔案：`rm -- -檔名` |

## 範例 {#examples}

```command
rm reports/error.bak
ls ~/reports/*.bak
rm ~/reports/*.bak
rm -r ~/practice
```

1. 第 3 段：刪掉練習用的備份。
2. 先看樣式會符合哪些檔案…
3. …確認後再刪。
4. 刪除整個目錄。
