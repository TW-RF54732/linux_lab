#!/usr/bin/env bash
# Linux Server 社課 lab：在 Ubuntu（Proxmox CT/LXC）內部署整套環境。
#
# 用法（在 CT 內以 root 執行）：
#   ./setup.sh             # 部署；已存在的學員帳號不會被改動預置檔
#   ./setup.sh --reseed    # 另外把所有學員的預置檔與服務狀態重新產生到初始值
#
# 可以重複執行（idempotent）。設定在同目錄的 lab.conf。

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lab.conf
source "$HERE/lab.conf"

RESEED=0
for arg in "$@"; do
    case "$arg" in
        --reseed) RESEED=1 ;;
        -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

STUDENT_GROUP=labusers
ADMIN_GROUP=labadmins
PACKAGES=(openssh-server libpam-systemd dbus-user-session nano less grep findutils procps python3 sudo)

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32mok\033[0m  %s\n' "$*"; }
warn() { printf '    \033[33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

student_name() { printf '%s%0*d' "$LAB_PREFIX" "$WIDTH" "$1"; }

# 以學員身分操作他的 systemd user manager
user_systemctl() {
    local u=$1; shift
    local uid; uid=$(id -u "$u")
    runuser -u "$u" -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user "$@"
}

gen_password() {
    python3 -c 'import secrets,sys; a="abcdefghjkmnpqrstuvwxyz23456789"; print("".join(secrets.choice(a) for _ in range(int(sys.argv[1]))))' "$LAB_PASSWORD_LEN"
}

# ------------------------------------------------------------------ 前置檢查
say "前置檢查"
[ "$(id -u)" -eq 0 ] || die "請用 root 執行（Proxmox 上可用 pct enter <CTID>）"
[ -d /run/systemd/system ] || die "PID 1 不是 systemd"
. /etc/os-release
case "$ID:$VERSION_ID" in
    ubuntu:24.04|ubuntu:22.04|debian:12) ok "$PRETTY_NAME" ;;
    *) warn "未測試的發行版：$PRETTY_NAME（規格以 Ubuntu 24.04 為準）" ;;
esac
VIRT=$(systemd-detect-virt -c 2>/dev/null || true)
ok "container: ${VIRT:-none}"
[[ "$LAB_COUNT" =~ ^[0-9]+$ ]] && [ "$LAB_COUNT" -ge 1 ] || die "LAB_COUNT 必須是正整數"
WIDTH=$(( ${#LAB_COUNT} < 2 ? 2 : ${#LAB_COUNT} ))
for f in files/lab-app files/lab-seed files/lab-app.service; do
    [ -f "$HERE/$f" ] || die "缺少 $f"
    if grep -q $'\r' "$HERE/$f"; then die "$f 是 CRLF 換行，請轉成 LF（例如 sed -i 's/\\r\$//' $f）"; fi
done

if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    ctrl=$(cat /sys/fs/cgroup/cgroup.controllers)
    for c in memory pids; do
        [[ " $ctrl " == *" $c "* ]] && ok "cgroup v2 controller: $c" \
            || warn "cgroup controller '$c' 不可用，資源限制（$c）不會生效"
    done
else
    warn "不是 cgroup v2，TasksMax/MemoryMax 可能不生效"
fi

# ------------------------------------------------------------------ 套件與時區
say "安裝套件"
export DEBIAN_FRONTEND=noninteractive
missing=()
for p in "${PACKAGES[@]}"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed" || missing+=("$p")
done
if [ ${#missing[@]} -gt 0 ]; then
    apt-get update -q
    apt-get install -y -q "${missing[@]}"
fi
ok "${PACKAGES[*]}"

say "時區：$LAB_TZ"
[ -f "/usr/share/zoneinfo/$LAB_TZ" ] || die "找不到時區 $LAB_TZ"
ln -sf "/usr/share/zoneinfo/$LAB_TZ" /etc/localtime
echo "$LAB_TZ" > /etc/timezone
ok "$(date '+%F %T %Z')"
if [ -n "$VIRT" ]; then
    ok "CT 的時鐘來自 Proxmox 主機，請確認主機有開 NTP（chrony）"
fi

# ------------------------------------------------------------------ 群組
say "群組"
getent group "$STUDENT_GROUP" >/dev/null || groupadd "$STUDENT_GROUP"
getent group "$ADMIN_GROUP"   >/dev/null || groupadd "$ADMIN_GROUP"
ok "$STUDENT_GROUP（學員）、$ADMIN_GROUP（管理者）"
for a in $LAB_ADMINS; do
    id "$a" >/dev/null 2>&1 || die "管理者帳號 $a 不存在，請先建立（例如 adduser $a）"
    usermod -aG "$ADMIN_GROUP" "$a"
    ok "管理者 $a 加入 $ADMIN_GROUP"
done

# ------------------------------------------------------------------ 程式與 service
say "安裝 /opt/lab 與 user service"
install -d -m 755 -o root -g root /opt/lab
install -d -m 700 -o root -g root /opt/lab/admin
install -m 755 -o root -g root "$HERE/files/lab-app"  /opt/lab/lab-app
install -m 700 -o root -g root "$HERE/files/lab-seed" /opt/lab/admin/lab-seed
install -m 644 -o root -g root "$HERE/files/lab-app.service" /etc/systemd/user/lab-app.service
systemctl --global enable lab-app.service >/dev/null 2>&1 || true
[ -L /etc/systemd/user/default.target.wants/lab-app.service ] || die "systemctl --global enable 失敗"
ok "/opt/lab/lab-app、/etc/systemd/user/lab-app.service（global enabled）"

# ------------------------------------------------------------------ 資源限制
say "資源限制（每位使用者）"
install -d -m 755 /etc/systemd/system/user-.slice.d
cat > /etc/systemd/system/user-.slice.d/lab.conf <<EOF
# Linux Server 社課 lab（由 setup.sh 產生）：每位使用者的程序數與記憶體上限
[Slice]
TasksMax=$LAB_TASKS_MAX
MemoryMax=$LAB_MEMORY_MAX
EOF
systemctl daemon-reload
ok "TasksMax=$LAB_TASKS_MAX MemoryMax=$LAB_MEMORY_MAX"

# ------------------------------------------------------------------ SSH
say "SSH 設定"
SSHD_DROPIN=/etc/ssh/sshd_config.d/00-lab.conf
grep -Eq '^\s*Include\s+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config \
    || die "/etc/ssh/sshd_config 沒有 Include sshd_config.d，請手動檢查"
cat > "$SSHD_DROPIN" <<EOF
# Linux Server 社課 lab（由 setup.sh 產生）
# sshd 採「第一個出現的值」為準，這個檔排在 sshd_config.d 最前面，會蓋過後面的設定。
UsePAM yes
PasswordAuthentication yes
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowGroups $STUDENT_GROUP $ADMIN_GROUP
MaxStartups $LAB_MAX_STARTUPS
EOF
chmod 644 "$SSHD_DROPIN"
mkdir -p /run/sshd
sshd -t || { rm -f "$SSHD_DROPIN"; die "sshd 設定檢查失敗，已移除 $SSHD_DROPIN"; }
eff=$(sshd -T 2>/dev/null)
for kv in "passwordauthentication yes" "pubkeyauthentication yes" "permitrootlogin no" \
          "usepam yes" "maxstartups $LAB_MAX_STARTUPS"; do
    grep -qx "$kv" <<<"$eff" && ok "$kv" || die "sshd 有效設定不是「$kv」，可能被其他設定檔蓋掉：$(grep "^${kv%% *} " <<<"$eff")"
done
grep -qi "^allowgroups .*$STUDENT_GROUP" <<<"$eff" && ok "allowgroups $STUDENT_GROUP $ADMIN_GROUP" \
    || die "AllowGroups 沒生效"
if systemctl list-unit-files ssh.socket >/dev/null 2>&1 && systemctl is-enabled --quiet ssh.socket 2>/dev/null; then
    systemctl try-restart ssh.service
    ok "ssh.socket（socket activation）"
else
    systemctl enable ssh.service >/dev/null 2>&1 || true
    systemctl restart ssh.service
    ok "ssh.service 已重新啟動"
fi
if [ -z "$LAB_ADMINS" ]; then
    warn "LAB_ADMINS 是空的：root 與其他非學員帳號將無法 SSH，請用 pct enter 管理"
fi

# ------------------------------------------------------------------ 學員帳號
say "學員帳號 $(student_name 1) … $(student_name "$LAB_COUNT")"
umask 077
[ -f "$LAB_ROSTER" ] || printf 'account,password\n' > "$LAB_ROSTER"
chmod 600 "$LAB_ROSTER"
umask 022

NEW_USERS=()
for i in $(seq 1 "$LAB_COUNT"); do
    u=$(student_name "$i")
    if id "$u" >/dev/null 2>&1; then
        usermod -aG "$STUDENT_GROUP" "$u"
    else
        useradd -m -s /bin/bash -U -G "$STUDENT_GROUP" "$u"
        pw=$(gen_password)
        echo "$u:$pw" | chpasswd
        sed -i "/^$u,/d" "$LAB_ROSTER"
        echo "$u,$pw" >> "$LAB_ROSTER"
        NEW_USERS+=("$u")
    fi
    for g in sudo adm admin wheel lxd; do
        if id -nG "$u" | tr ' ' '\n' | grep -qx "$g"; then gpasswd -d "$u" "$g" >/dev/null; fi
    done
    usermod -s /bin/bash "$u"
    home=$(getent passwd "$u" | cut -d: -f6)
    chown "$u:$u" "$home"
    chmod 750 "$home"
done
ok "共 $LAB_COUNT 個帳號，新建 ${#NEW_USERS[@]} 個；密碼名單：$LAB_ROSTER"

# ------------------------------------------------------------------ 預置檔與初始狀態
# 初始狀態：lab-app 為 failed，app.log 最後一筆是 app is disabled 的 ERROR。
# 做法：先產生沒有最後那筆 ERROR 的 app.log，再真的啟動 lab-app，讓它自己寫出 ERROR 並以 78 結束。
init_user() {
    local u=$1 uid home i st
    uid=$(id -u "$u")
    home=$(getent passwd "$u" | cut -d: -f6)

    loginctl enable-linger "$u"
    for i in $(seq 1 60); do
        systemctl is-active --quiet "user@$uid.service" && [ -S "/run/user/$uid/bus" ] && break
        sleep 0.5
    done
    if ! systemctl is-active --quiet "user@$uid.service"; then
        warn "$u 的 user@$uid.service 沒有起來"
        warn "Proxmox CT 請確認 features: nesting=1（pct set <CTID> --features nesting=1 後重開 CT）"
        return 1
    fi
    # 等 user manager 開機完成（lab-app 可能已經跑過一次並失敗）
    timeout 60 runuser -u "$u" -- env XDG_RUNTIME_DIR="/run/user/$uid" \
        systemctl --user is-system-running --wait >/dev/null 2>&1 || true

    user_systemctl "$u" stop lab-app.service >/dev/null 2>&1 || true
    /opt/lab/admin/lab-seed "$u" --seed "$LAB_SEED" --no-final-error
    user_systemctl "$u" reset-failed lab-app.service >/dev/null 2>&1 || true
    user_systemctl "$u" start lab-app.service >/dev/null 2>&1 || true

    for i in $(seq 1 20); do
        st=$(user_systemctl "$u" show -p ActiveState --value lab-app.service 2>/dev/null || true)
        [ "$st" = failed ] && break
        sleep 0.5
    done
    if [ "$st" != failed ]; then
        warn "$u 的 lab-app 狀態是 '$st'，預期 failed"
        return 1
    fi
    if ! tail -n 1 "$home/.log/app.log" | grep -q 'ERROR: app is disabled'; then
        warn "$u 的 app.log 最後一筆不是 app is disabled"
        return 1
    fi
    return 0
}

say "預置檔與初始狀態"
fail=0
for i in $(seq 1 "$LAB_COUNT"); do
    u=$(student_name "$i")
    home=$(getent passwd "$u" | cut -d: -f6)
    if [ "$RESEED" -eq 1 ] || [ ! -f "$home/.log/app.log" ] || [ ! -f "$home/.config/app/config.json" ]; then
        if init_user "$u"; then ok "$u 初始化完成"; else fail=$((fail + 1)); fi
    else
        loginctl enable-linger "$u"
        ok "$u 已有預置檔，略過（要重來請加 --reseed）"
    fi
done
[ "$fail" -eq 0 ] || die "$fail 個帳號初始化失敗，請看上面的訊息"

say "完成"
cat <<EOF
    學員帳號：$(student_name 1) … $(student_name "$LAB_COUNT")
    密碼名單：$LAB_ROSTER
    驗證：    $HERE/verify.sh
    手動測試：ssh $(student_name 1)@<CT 的 IP>
EOF
