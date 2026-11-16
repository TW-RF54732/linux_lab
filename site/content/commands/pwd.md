---
title: pwd
summary: 我現在在哪個目錄
description: 印出你目前所在目錄的完整路徑。迷路時第一個要打的指令。
---

## 常用 {#basics}

```command
pwd
```

```output
/home/lab07/.log
```

| 寫法 | 做什麼 |
| --- | --- |
| `pwd` | 印出目前目錄的完整路徑 |

提示字元裡也看得到目前目錄（`lab07@linux-lab:~/.log$`），但家目錄會縮寫成 `~`；`pwd` 一律印出完整路徑。

## 進階 {#advanced}

| 選項 | 做什麼 |
| --- | --- |
| `-P` | 遇到捷徑（符號連結）時，印出真正的位置 |

## 範例 {#examples}

```command
cd ~/.log
pwd
cd ..
pwd
```

進入 `.log` 後是 `/home/lab07/.log`，往上一層回到 `/home/lab07`。
