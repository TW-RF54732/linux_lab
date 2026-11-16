#!/usr/bin/env bash
# 在 Proxmox 主機上建立 lab 用的 Ubuntu 24.04 CT，並把本專案推進去執行 setup.sh。
#
# 用法（在 Proxmox 主機以 root 執行，先把整個 linux_lab 目錄複製到主機上）：
#   CTID=240 IP=192.168.10.50/24 GW=192.168.10.1 ./proxmox/create-ct.sh
#
# 已存在的 CT 不會重建，只會確認 nesting、推檔案、跑 setup.sh。

set -euo pipefail

CTID=${CTID:?請指定 CTID，例如 CTID=240}
HOSTNAME_=${HOSTNAME_:-linux-lab}
STORAGE=${STORAGE:-local-lvm}          # rootfs 放哪個 storage
TEMPLATE_STORAGE=${TEMPLATE_STORAGE:-local}
BRIDGE=${BRIDGE:-vmbr0}
IP=${IP:-dhcp}                         # 例如 192.168.10.50/24，或 dhcp
GW=${GW:-}
CORES=${CORES:-2}
MEMORY=${MEMORY:-4096}
SWAP=${SWAP:-512}
DISK_GB=${DISK_GB:-10}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v pct >/dev/null || { echo "請在 Proxmox 主機上執行" >&2; exit 1; }

if ! pct status "$CTID" >/dev/null 2>&1; then
    echo "==> 找 Ubuntu 24.04 template"
    tpl=$(pveam list "$TEMPLATE_STORAGE" | awk '/ubuntu-24\.04-standard/ {print $1}' | sort -V | tail -n 1)
    if [ -z "$tpl" ]; then
        pveam update >/dev/null
        name=$(pveam available --section system | awk '/ubuntu-24\.04-standard/ {print $2}' | sort -V | tail -n 1)
        [ -n "$name" ] || { echo "pveam 找不到 ubuntu-24.04-standard" >&2; exit 1; }
        pveam download "$TEMPLATE_STORAGE" "$name"
        tpl="$TEMPLATE_STORAGE:vztmpl/$name"
    fi
    echo "    $tpl"

    net="name=eth0,bridge=$BRIDGE,ip=$IP"
    [ -n "$GW" ] && net="$net,gw=$GW"

    echo "==> 建立 CT $CTID"
    # nesting=1：Ubuntu 24.04 的 systemd 255 需要它，systemd --user 與 logind 才能正常運作
    pct create "$CTID" "$tpl" \
        --hostname "$HOSTNAME_" \
        --cores "$CORES" --memory "$MEMORY" --swap "$SWAP" \
        --rootfs "$STORAGE:$DISK_GB" \
        --net0 "$net" \
        --unprivileged 1 \
        --features nesting=1 \
        --onboot 1 \
        --ostype ubuntu
else
    echo "==> CT $CTID 已存在"
    if ! pct config "$CTID" | grep -Eq '^features:.*nesting=1'; then
        echo "    開啟 nesting=1（需要重開 CT）"
        pct set "$CTID" --features nesting=1
        pct status "$CTID" | grep -q running && pct reboot "$CTID"
    fi
fi

pct status "$CTID" | grep -q running || pct start "$CTID"
echo "==> 等 CT 開機"
for _ in $(seq 1 60); do
    state=$(pct exec "$CTID" -- systemctl is-system-running 2>/dev/null || true)
    case "$state" in running|degraded) break ;; esac
    sleep 1
done
echo "    systemd: ${state:-unknown}"

echo "==> 推送檔案到 CT:/root/linux_lab"
pct exec "$CTID" -- mkdir -p /root/linux_lab/files
for f in setup.sh verify.sh lab.conf files/lab-app files/lab-seed files/lab-app.service; do
    perms=644
    case "$f" in *.sh|files/lab-app|files/lab-seed) perms=755 ;; esac
    pct push "$CTID" "$HERE/$f" "/root/linux_lab/$f" --perms "$perms"
done
pct exec "$CTID" -- sed -i 's/\r$//' /root/linux_lab/setup.sh /root/linux_lab/verify.sh \
    /root/linux_lab/lab.conf /root/linux_lab/files/lab-app /root/linux_lab/files/lab-seed \
    /root/linux_lab/files/lab-app.service

echo "==> 執行 setup.sh"
pct exec "$CTID" -- /root/linux_lab/setup.sh
echo
echo "完成。驗證：pct exec $CTID -- /root/linux_lab/verify.sh --scenarios --fork-test"
echo "密碼名單：pct exec $CTID -- cat /root/lab-roster.csv"
