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
touch demo.sh
ls -l demo.sh
chmod +x demo.sh
ls -l demo.sh
```

```output
-rw-r--r-- 1 lab07 lab07 0 Nov 21 14:05 demo.sh
-rwxr-xr-x 1 lab07 lab07 0 Nov 21 14:05 demo.sh
```

第 4 段：三段都多了 `x`。

改別人的檔案會出現 `Operation not permitted`。
