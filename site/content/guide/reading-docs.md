---
title: 如何查指令
nav: 如何查指令
summary: 用 --help、man、help 自己查
description: 忘記參數時不用上網搜尋，在終端機裡就能查。順便看懂說明裡的方括號與大寫字。
---

## 常用 {#basics}

```command
ls --help
```

| 寫法 | 什麼時候用 |
| --- | --- |
| `指令 --help` | 最快，大部分指令都有。例如 `ls --help` |
| `man 指令` | 完整手冊。例如 `man ls`，按 [[q]] 離開 |
| `help 指令` | `cd`、`exit`、`jobs` 這類 shell 內建指令用這個 |

說明太長時接 `less` 慢慢看：`ls --help | less`。

## 看懂說明的符號 {#synopsis}

說明的第一行通常長這樣：

```reference
ls [OPTION]... [FILE]...
```

| 符號 | 意思 |
| --- | --- |
| `[ ]` | 可以省略 |
| `...` | 可以給很多個 |
| 大寫字，如 `FILE` | 換成你自己的值，例如 `app.log` |
| `<PID>` | 同上，換成你的值 |

> [!WARNING]
> 方括號、角括號只是說明用的，**不要真的打出來**。`kill <PID>` 要打成 `kill 1234`。

## 選項的寫法 {#options}

| 寫法 | 說明 |
| --- | --- |
| `-a` | 短選項，一個減號一個字母 |
| `--all` | 長選項，兩個減號一個單字，和 `-a` 一樣 |
| `-la` | 多個短選項可以合在一起，等於 `-l -a` |
| `-n 5`、`--lines=5` | 需要值的選項 |

大小寫有差：`ls -r` 和 `ls -R` 是不同的選項。

## 進階 {#advanced}

### 在 man 裡移動 {#man-keys}

`man` 的操作和 [less](/commands/less/) 一樣：

| 按鍵 | 動作 |
| --- | --- |
| [[Space]] / [[b]] | 下一頁 / 上一頁 |
| `/文字` | 搜尋，[[n]] 找下一個 |
| [[q]] | 離開 |

### 不知道指令名稱 {#search}

```command
man -k password
```

列出標題有 password 的所有手冊。

### 判斷是哪一種指令 {#type}

```command
type cd ls
```

```output
cd is a shell builtin
ls is aliased to `ls --color=auto'
```

`shell builtin` 用 `help` 查，其他用 `--help` 或 `man`。

> [!NOTE]
> 伺服器若沒裝某份手冊，`man` 會說 `No manual entry`，改用 `--help`，或上 [Ubuntu 線上手冊](https://manpages.ubuntu.com/) 查。

## 範例 {#examples}

課堂沒教怎麼讓 `ls` 依時間排序，試著自己查：

1. `ls --help | less`
2. 輸入 `/time` 搜尋，找到 `-t`：sort by time, newest first。
3. 執行 `ls -lt ~/.log`，最新的檔案排在最上面。
