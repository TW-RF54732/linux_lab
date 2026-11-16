---
title: 家目錄與預置檔案
nav: 家目錄與預置檔案
summary: ~/.log 與 ~/.config 裡有什麼
description: 每位學員家目錄裡預先放好的 log 與設定檔。
---

## 常用 {#basics}

```reference
~/
├── .log/
│   ├── app.log        ← lab-app 的 log，要找的錯誤在這裡
│   ├── access.log     ← 其他都是雜訊
│   ├── db.log
│   ├── cron.log
│   └── boot.log
└── .config/
    ├── app/config.json   ← lab-app 的設定檔，第 5 段要改
    └── 其他 7 個目錄       ← 別的程式的設定，不要改錯
```

| 檔案 | 用途 |
| --- | --- |
| `~/.log/app.log` | lab-app 的 log，約 2000 行，最後一筆 ERROR 就是現在的問題 |
| `~/.config/app/config.json` | lab-app 的設定，一開始是 `{"enable": false}` |

`.log` 和 `.config` 以 `.` 開頭，是隱藏目錄，要用 `ls -a` 才看得到。

## 進階 {#advanced}

### app.log 的格式 {#app-log}

```reference
日期 時間 等級: 訊息
```

```output
2026-11-21 13:58:52 INFO: reading app/config.json
2026-11-21 13:59:31 ERROR: app is disabled, set "enable" to true in app/config.json
```

| 等級 | 意思 |
| --- | --- |
| `INFO` | 一般紀錄 |
| `WARN` | 值得注意，但沒壞 |
| `ERROR` | 錯誤。前面 7 筆是已經解決的舊問題，**最後一筆**才是現在的 |

### 其他 log {#other-logs}

`access.log`、`db.log`、`cron.log`、`boot.log` 都是雜訊，讓你練習挑對檔案。它們都沒有 `ERROR` 這個字。

### 其他設定目錄 {#other-configs}

`~/.config` 裡還有 `chat-bot`、`monitor`、`backup-agent` 等目錄，其中幾個也有 `config.json`，`chat-bot` 的也是 `"enable": false`。改之前看清楚路徑裡是不是 `app`。

### 一開始不存在的東西 {#absent}

`~/reports`、`~/error.txt`、`~/.ssh` 都要你在課堂上自己建立。

## 範例 {#examples}

```command
ls -la ~
ls -lh ~/.log
grep -r ERROR ~/.log
find ~/.config -name config.json
```

1. 看到 `.log`、`.config`。
2. 各個 log 的大小。
3. 一次搜尋所有 log，只有 `app.log` 有 ERROR。
4. 找到好幾個 `config.json`，靠路徑判斷哪一個是 `app` 的。

### 改壞了怎麼辦 {#reset}

```command
cp ~/.config/app/config.json.bak ~/.config/app/config.json
```

沒有備份的話，直接寫回初始內容：

```command
echo '{"enable": false}' > ~/.config/app/config.json
```
