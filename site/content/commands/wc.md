---
title: wc
summary: 數行數
description: 計算檔案有幾行、幾個字、多少位元組。最常接在管線後面數「有幾筆」。
---

## 常用 {#basics}

```command
grep ERROR app.log | wc -l
```

| 寫法 | 做什麼 |
| --- | --- |
| `wc -l 檔案` | 有幾行 |
| `指令 \| wc -l` | 前一個指令輸出了幾行 |

## 進階 {#advanced}

| 選項 | 做什麼 |
| --- | --- |
| `wc 檔案` | 不加選項：行數、字數、位元組數一起印 |
| `-w` | 字數（以空白分隔） |
| `-c` | 位元組數 |
| `-m` | 字元數（中文一個字算 1） |

## 範例 {#examples}

```command
grep ERROR app.log | wc -l
wc -l ~/.log/*.log
ls ~/.config | wc -l
```

1. ERROR 有幾筆（結果是 8）。
2. 每個 log 有幾行，最後一行是總和。
3. `.config` 底下有幾個目錄。
