---
title: ln
summary: 建立連結（捷徑）
description: 建立一個指向別的檔案的連結，打開連結就等於打開原本的檔案。幾乎都用 ln -s（符號連結）。
---

## 常用 {#basics}

```command
ln -s /etc/os-release ~/os-release
```

| 寫法 | 做什麼 |
| --- | --- |
| `ln -s 原本的檔案 連結名稱` | 建立符號連結，像 Windows 的捷徑 |
| `ls -l 連結名稱` | 看連結指向哪裡 |
| `rm 連結名稱` | 刪掉連結，原本的檔案不受影響 |

順序和 [cp](/commands/cp/) 一樣：**先寫原本的檔案，再寫新的名字**。

符號連結本身不存內容，讀它就是讀原本的檔案。原本的檔案改了，透過連結看到的也跟著變。

## 進階 {#advanced}

| 寫法 | 做什麼 |
| --- | --- |
| `ln -s 檔案 目錄/` | 在目錄裡建立同名的連結 |
| `ln -sf 檔案 連結名稱` | 連結名稱已經存在時直接蓋掉 |
| `readlink 連結名稱` | 只印出它指向的路徑 |
| `ln 檔案 連結名稱` | 不加 `-s` 是「硬連結」，限制很多，一般用不到 |

### 用絕對路徑 {#absolute}

`ln -s` 的第一個參數會**原封不動**存進連結。寫相對路徑時，是從連結所在的目錄去找，不是從你現在的位置。用 `/` 開頭的絕對路徑最不容易出錯。

## 範例 {#examples}

```command
ln -s /etc/os-release ~/os-release
ls -l ~/os-release
cat ~/os-release
rm ~/os-release
```

```output
lrwxrwxrwx 1 lab07 lab07 15 Nov 21 14:05 /home/lab07/os-release -> /etc/os-release
```

1. 在家目錄建立一個指向 `/etc/os-release` 的連結。
2. 權限開頭是 `l`，`->` 後面是它指向的檔案。
3. 讀連結就是讀原本的檔案。
4. 只刪掉連結，`/etc/os-release` 還在。

連結的權限永遠顯示 `rwxrwxrwx`，真正有效的是原本那個檔案的權限：原本的檔案你讀不到，透過連結也讀不到。

## 常見錯誤 {#errors}

| 訊息 | 原因 |
| --- | --- |
| `failed to create hard link ...: Invalid cross-device link` | 忘了加 `-s`。硬連結不能跨磁碟，改用 `ln -s` |
| `failed to create hard link ...: Operation not permitted` | 忘了加 `-s`。不能對別人的檔案建立硬連結，改用 `ln -s` |
| `failed to create symbolic link ...: File exists` | 連結名稱已經有檔案了，先 `rm` 掉或用 `ln -sf` |
| 讀連結時 `No such file or directory` | 連結指向的檔案不存在（斷掉的連結），通常是路徑打錯或用了相對路徑。`ls -l` 看 `->` 後面，`rm` 掉重做 |
