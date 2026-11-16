---
title: cp
summary: 複製
description: 複製檔案或目錄。改設定之前先 cp 一份備份，是維運的基本習慣。
---

## 常用 {#basics}

```command
cp config.json config.json.bak
```

| 寫法 | 做什麼 |
| --- | --- |
| `cp 來源 新檔名` | 複製一份 |
| `cp 來源 目錄/` | 複製到目錄裡，名稱不變 |
| `cp -r 來源目錄 新目錄` | 複製整個目錄 |
| `cp -i 來源 目的` | 會覆蓋時先詢問 |

> [!WARNING]
> 目的檔已經存在時，`cp` 會**直接覆蓋，不會問**。怕蓋錯就加 `-i`。

## 進階 {#advanced}

| 選項 | 做什麼 |
| --- | --- |
| `-p` | 保留原檔的時間與權限 |
| `-a` | 完整保留所有屬性並包含子目錄，備份目錄時用 |
| `-n` | 不覆蓋已存在的檔案 |
| `-v` | 顯示複製了什麼 |
| `-u` | 只在來源比較新時才複製 |

## 範例 {#examples}

```command
cp config.json config.json.bak
cp config.json.bak config.json
cp reports/error.txt reports/error.bak
cp -r ~/.config/app ~/app-backup
```

1. 第 5 段：改設定前先備份。
2. 改壞了，用備份蓋回去。
3. 第 2 段：練習複製。
4. 備份整個目錄。

複製目錄忘了加 `-r` 會看到 `-r not specified; omitting directory`。
