---
title: mv
summary: 移動或改名
description: 把檔案移到別的地方，或改名字。Linux 沒有獨立的改名指令，改名就是用 mv。
---

## 常用 {#basics}

```command
mv error.txt reports/
```

| 寫法 | 做什麼 |
| --- | --- |
| `mv 檔案 目錄/` | 移進目錄 |
| `mv 舊名 新名` | 改名 |
| `mv -i 來源 目的` | 會覆蓋時先詢問 |

移動目錄不需要 `-r`。目的地已有同名檔案時會**直接覆蓋**。

## 進階 {#advanced}

| 選項 | 做什麼 |
| --- | --- |
| `-n` | 不覆蓋已存在的檔案 |
| `-v` | 顯示移動了什麼 |
| `-b` | 覆蓋前把舊檔備份成 `檔名~` |

## 範例 {#examples}

```command
mv error.txt reports/
mv demo.sh hello.sh
mv reports/error.txt .
```

1. 第 3 段：把報告移進 `reports`。結尾的 `/` 表示「這是目錄」，目錄不存在時會報錯，而不是不小心把檔案改名成 `reports`。
2. 改名。
3. 移回目前目錄（`.`）。
