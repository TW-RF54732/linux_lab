---
title: nano
summary: 文字編輯器
description: 在終端機裡編輯文字檔。畫面下方隨時顯示快捷鍵，是最容易上手的編輯器。
---

## 常用 {#basics}

```command
nano config.json
```

開啟後直接打字就是輸入，用方向鍵移動。

| 按鍵 | 做什麼 |
| --- | --- |
| 方向鍵 | 移動游標 |
| [[Ctrl+O]] 再按 [[Enter]] | 存檔 |
| [[Ctrl+X]] | 離開。有沒存的修改會問：[[Y]] 存、[[N]] 不存 |
| [[Ctrl+W]] | 搜尋 |
| [[Ctrl+K]] / [[Ctrl+U]] | 剪下整行 / 貼上 |

畫面下方的 `^` 代表 [[Ctrl]]，`M-` 代表 [[Alt]]。例如 `^X` 就是 [[Ctrl+X]]。

## 進階 {#advanced}

| 按鍵或選項 | 做什麼 |
| --- | --- |
| [[Alt+U]] / [[Alt+E]] | 復原 / 重做 |
| [[Ctrl+\]] | 搜尋並取代 |
| [[Ctrl+_]] | 跳到第幾行 |
| [[Ctrl+C]] | 顯示游標在第幾行 |
| [[Ctrl+G]] | 顯示所有快捷鍵 |
| `nano -l 檔案` | 顯示行號 |
| `nano -v 檔案` | 唯讀模式，只看不改 |
| `nano -B 檔案` | 存檔時自動備份原檔成 `檔名~` |

## 範例 {#examples}

第 5 段：

```command
cd ~/.config/app
cp config.json config.json.bak
nano config.json
```

1. 把游標移到 `false` 後面。
2. [[Backspace]] 刪掉 `false`，輸入 `true`（小寫、不加引號）。
3. [[Ctrl+O]]，再 [[Enter]] 確認檔名。
4. [[Ctrl+X]] 離開。
5. `cat config.json` 確認變成 `{"enable": true}`。

只改那幾個字母，引號、冒號、大括號都不要動。改壞了見 [lab-app 錯誤訊息](/environment/lab-app/#errors)。

> [!TIP]
> 開到檔名打錯的檔案時，下方會顯示 `[ New File ]`。直接 [[Ctrl+X]] 離開，不會建立檔案。
