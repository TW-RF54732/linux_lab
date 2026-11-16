---
title: less
summary: 分頁瀏覽大檔案
description: 一頁一頁地看檔案，可以往回翻、搜尋。看大檔案時用它取代 cat。
---

## 常用 {#basics}

```command
less app.log
```

開啟後用按鍵操作：

| 按鍵 | 做什麼 |
| --- | --- |
| [[Space]] | 下一頁 |
| [[b]] | 上一頁 |
| `/文字` 再按 [[Enter]] | 往下搜尋，例如 `/ERROR` |
| [[n]] / [[N]] | 下一個 / 上一個搜尋結果 |
| [[g]] / [[G]] | 跳到開頭 / 結尾 |
| [[q]] | 離開 |

`man` 也是用 `less` 顯示，按鍵完全一樣。

## 進階 {#advanced}

| 按鍵或選項 | 做什麼 |
| --- | --- |
| [[↑]] [[↓]] | 一次一行 |
| `?文字` | 往上搜尋 |
| [[F]] | 持續顯示新增的內容（像 `tail -f`），[[Ctrl+C]] 停止 |
| `less -N 檔案` | 顯示行號 |
| `less -S 檔案` | 長行不換行，用左右鍵捲動 |
| `less +G 檔案` | 開啟後直接跳到結尾 |
| [[h]] | 顯示所有按鍵說明 |

## 範例 {#examples}

```command
less ~/.log/app.log
```

進去之後依序練習：[[Space]] 往下、[[b]] 往回、`/ERROR` 搜尋、[[n]] 找下一個、[[G]] 跳到結尾（最後一筆 ERROR 就在那）、[[q]] 離開。

```command
grep ERROR app.log | less
```

把 `grep` 的結果接給 `less` 慢慢看。
