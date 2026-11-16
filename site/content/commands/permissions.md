---
title: 檔案權限
nav: 檔案權限
summary: 看懂 rwx 與 644、755、600
description: 每個檔案都記錄著誰可以讀、寫、執行。看懂 ls -l 的那一串 rwx，就知道自己能做什麼。
---

## 常用 {#basics}

```command
ls -l ~/.config/app/config.json
```

```output
-rw-r--r-- 1 lab07 lab07 18 Nov 21 13:45 config.json
```

`-rw-r--r--` 拆成四段：

```reference
-    rw-     r--    r--
類型  擁有者   群組    其他人
```

| 字母 | 意思 | 數字 |
| --- | --- | --- |
| `r` | 讀 | 4 |
| `w` | 寫 | 2 |
| `x` | 執行 | 1 |
| `-` | 沒有這個權限 | 0 |

每段的數字相加就是權限值，`rw-` = 4+2 = 6，所以 `rw-r--r--` 就是 `644`。

| 權限值 | 符號 | 常見用途 |
| --- | --- | --- |
| `644` | `rw-r--r--` | 一般檔案 |
| `755` | `rwxr-xr-x` | 程式、一般目錄 |
| `600` | `rw-------` | 私密檔案，例如 `authorized_keys` |
| `700` | `rwx------` | 私密目錄，例如 `~/.ssh` |

## 進階 {#advanced}

### 系統怎麼判斷 {#model}

你是擁有者就看第一段；不是但在該群組就看第二段；都不是就看第三段。用 [id](/commands/id/) 看自己屬於哪些群組。root 不受權限限制。

### 目錄的權限 {#directories}

| 字母 | 對目錄的意思 |
| --- | --- |
| `r` | 可以列出裡面有什麼（`ls`） |
| `w` | 可以在裡面新增、刪除、改名檔案 |
| `x` | 可以進入（`cd`） |

你的家目錄是 `750`，其他人連 `cd` 都進不去，所以同學之間看不到彼此的檔案。

### SSH 為什麼要 700 與 600 {#ssh}

`authorized_keys` 決定誰可以不用密碼登入你的帳號。如果別人能改它，就能把自己的公鑰加進去冒用你。所以權限太寬時，SSH 會直接忽略它。

## 範例 {#examples}

```command
id
ls -l /etc/shadow
cat /etc/shadow
```

```output
-rw-r----- 1 root shadow 1024 Nov 21 09:00 /etc/shadow
cat: /etc/shadow: Permission denied
```

擁有者是 root、群組是 shadow，你兩個都不是，套用最後一段 `---`，什麼都不能做。修改權限見 [chmod](/commands/chmod/)。
