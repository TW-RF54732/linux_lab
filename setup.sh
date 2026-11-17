#!/usr/bin/env bash
# Linux Server 社課 lab：在 Ubuntu（Proxmox CT/LXC）內部署整套環境。
#
# 用法（在 CT 內以 root 執行）：
#   ./setup.sh             # 部署；已存在的學員帳號不會被改動預置檔
#   ./setup.sh --reseed    # 另外把所有學員的預置檔、服務狀態與 challange 重新產生到初始值
#   ./setup.sh --reseed-user lab05 [--reseed-user lab06 ...]   # 只還原指定學員
#
# 可以重複執行（idempotent）。設定在同目錄的 lab.conf。

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$HERE/lab.conf" ]]; then
    echo "找不到 $HERE/lab.conf；請先執行：cp lab.conf.example lab.conf，並依需求修改" >&2
    exit 1
fi
# shellcheck source=lab.conf.example
source "$HERE/lab.conf"

RESEED=0
RESEED_USERS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --reseed) RESEED=1 ;;
        --reseed-user)
            [ $# -ge 2 ] || { echo "--reseed-user 需要帳號名稱" >&2; exit 2; }
            RESEED_USERS+=("$2"); shift ;;
        --reseed-user=*) RESEED_USERS+=("${1#*=}") ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

STUDENT_GROUP=labusers
ADMIN_GROUP=labadmins
PACKAGES=(openssh-server libpam-systemd dbus-user-session nano less grep findutils procps python3 sudo openssl)
LESSON_DIR=/var/lib/lab/lesson

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
for f in files/lab-app files/lab-seed files/lab-app.service \
         files/evil-killer files/evil-killer.service files/lab files/lab-challange; do
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

# challange：evil-killer 不做 --global enable，闖關開始時由講師 sudo lab --start 啟動
install -m 755 -o root -g root "$HERE/files/evil-killer" /opt/lab/evil-killer
install -m 644 -o root -g root "$HERE/files/evil-killer.service" /etc/systemd/user/evil-killer.service
install -m 700 -o root -g root "$HERE/files/lab-challange" /opt/lab/admin/lab-challange
install -m 755 -o root -g root "$HERE/files/lab" /usr/local/bin/lab
install -d -m 755 -o root -g root /var/lib/lab /var/lib/lab/users "$LESSON_DIR"
install -d -m 700 -o root -g root /var/lib/lab/answers
install -d -m 755 -o root -g root /var/lib/lab/progress
/opt/lab/admin/lab-challange key || die "/lab/key.txt 產生或檢查失敗"
ok "/opt/lab/evil-killer、/etc/systemd/user/evil-killer.service、/usr/local/bin/lab、/lab/key.txt"

# 學員讀不到 sshd 的 journal：由 root 常駐把每人的登入／金鑰登入／下載紀錄整理成
# /var/lib/lab/progress/labNN.json（root:labNN 640），學員端 lab 讀這份快取。
cat > /etc/systemd/system/lab-progress.service <<'EOF'
# Linux Server 社課 lab（由 setup.sh 產生）
[Unit]
Description=lab 進度快取（journal 的登入與下載紀錄 → 學員端 lab）
After=systemd-journald.service

[Service]
ExecStart=/usr/local/bin/lab --refresh --loop 5
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable lab-progress.service >/dev/null 2>&1
systemctl restart lab-progress.service   # restart：讓更新後的 lab 生效
systemctl is-active --quiet lab-progress.service || die "lab-progress.service 沒有起來：systemctl status lab-progress"
ok "lab-progress.service（每 5 秒更新學員端的進度快取）"

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
if [ "${LAB_ROOT_SSH:-0}" = 1 ]; then
    ROOT_LOGIN=prohibit-password
    usermod -aG "$ADMIN_GROUP" root
else
    ROOT_LOGIN=no
fi
grep -Eq '^\s*Include\s+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config \
    || die "/etc/ssh/sshd_config 沒有 Include sshd_config.d，請手動檢查"
write_sshd_dropin() {  # write_sshd_dropin <1=加 sftp 讀檔紀錄>
    cat > "$SSHD_DROPIN" <<EOF
# Linux Server 社課 lab（由 setup.sh 產生）
# sshd 採「第一個出現的值」為準，這個檔排在 sshd_config.d 最前面，會蓋過後面的設定。
UsePAM yes
PasswordAuthentication yes
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin $ROOT_LOGIN
AllowGroups $STUDENT_GROUP $ADMIN_GROUP
MaxStartups $LAB_MAX_STARTUPS
# 學員端 lab 讀 \$SSH_USER_AUTH 判斷這次是不是用金鑰登入（第 2 段檢查點）
ExposeAuthInfo yes
EOF
    if [ "$1" -eq 1 ]; then
        cat >> "$SSHD_DROPIN" <<'EOF'
# 記錄 scp/sftp 讀了哪些檔，lab --all 用來判斷 error.txt 有沒有被拉回筆電（第 3 段檢查點）
Subsystem sftp internal-sftp -l INFO
EOF
    fi
    chmod 644 "$SSHD_DROPIN"
}
mkdir -p /run/sshd
ssh-keygen -A >/dev/null 2>&1   # 補齊缺少的 host key（CT 範本常常沒有）
ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1 || die "沒有 SSH host key，ssh-keygen -A 失敗"
write_sshd_dropin 1
if ! sshd -t 2>/dev/null; then
    # 舊版 OpenSSH 遇到重複的 Subsystem（主設定檔已有一行）會直接報錯
    write_sshd_dropin 0
    sshd -t || { rm -f "$SSHD_DROPIN"; die "sshd 設定檢查失敗，已移除 $SSHD_DROPIN"; }
    warn "sshd 不接受 drop-in 裡的 Subsystem，第 3 段「已下載 error.txt」偵測停用（計分板只會到 △）"
fi
eff=$(sshd -T 2>/dev/null)
for kv in "passwordauthentication yes" "pubkeyauthentication yes" "permitrootlogin $ROOT_LOGIN" \
          "usepam yes" "maxstartups $LAB_MAX_STARTUPS" "exposeauthinfo yes"; do
    grep -qx "$kv" <<<"$eff" && ok "$kv" || die "sshd 有效設定不是「$kv」，可能被其他設定檔蓋掉：$(grep "^${kv%% *} " <<<"$eff")"
done
grep -qi "^allowgroups .*$STUDENT_GROUP" <<<"$eff" && ok "allowgroups $STUDENT_GROUP $ADMIN_GROUP" \
    || die "AllowGroups 沒生效"
if grep -qix "subsystem sftp internal-sftp -l INFO" <<<"$eff"; then
    ok "subsystem sftp internal-sftp -l INFO（記錄下載）"
else
    warn "sftp 沒有記錄讀檔（$(grep -i '^subsystem ' <<<"$eff")），第 3 段下載偵測停用"
fi
if systemctl list-unit-files ssh.socket >/dev/null 2>&1 && systemctl is-enabled --quiet ssh.socket 2>/dev/null; then
    systemctl try-restart ssh.service
    ok "ssh.socket（socket activation）"
else
    systemctl enable ssh.service >/dev/null 2>&1 || true
    systemctl restart ssh.service
    ok "ssh.service 已重新啟動"
fi
# 檢核：sshd 真的在跑、22 port 有回應 SSH banner
systemctl is-active --quiet ssh.service || systemctl is-active --quiet ssh.socket \
    || die "ssh 服務沒有啟動（systemctl status ssh）"
banner=""
for _ in 1 2 3 4 5; do
    banner=$(timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/22 && head -n1 <&3' 2>/dev/null) && [ -n "$banner" ] && break
    sleep 1
done
case "$banner" in SSH-*) ok "127.0.0.1:22 回應 $banner" ;; *) die "127.0.0.1:22 沒有 SSH banner" ;; esac
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
    # 預建 ~/.ssh（700）與空的 authorized_keys（600），學員第 2 段只要把公鑰 >> 進去。
    # 已經有的不清空（裡面可能是學員的公鑰），只修正擁有者與權限；是符號連結就不碰。
    ssh_dir="$home/.ssh"
    if [ -L "$ssh_dir" ] || [ -L "$ssh_dir/authorized_keys" ]; then
        warn "$u 的 ~/.ssh 或 authorized_keys 是符號連結，略過"
    else
        install -d -m 700 -o "$u" -g "$u" "$ssh_dir"
        [ -e "$ssh_dir/authorized_keys" ] || install -m 600 -o "$u" -g "$u" /dev/null "$ssh_dir/authorized_keys"
        chown "$u:$u" "$ssh_dir/authorized_keys"
        chmod 600 "$ssh_dir/authorized_keys"
    fi
done
ok "共 $LAB_COUNT 個帳號，新建 ${#NEW_USERS[@]} 個；密碼名單：$LAB_ROSTER；已預建 ~/.ssh/authorized_keys"

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
    # 教學關卡檢查點的基準時間：lab --all 只看這之後的登入與下載紀錄
    date +%s > "$LESSON_DIR/$u"
    return 0
}

for r in "${RESEED_USERS[@]}"; do
    found=0
    for i in $(seq 1 "$LAB_COUNT"); do
        [ "$(student_name "$i")" = "$r" ] && found=1
    done
    [ "$found" -eq 1 ] || die "--reseed-user：$r 不是學員帳號（$(student_name 1) … $(student_name "$LAB_COUNT")）"
done

say "預置檔與初始狀態"
fail=0
for i in $(seq 1 "$LAB_COUNT"); do
    u=$(student_name "$i")
    home=$(getent passwd "$u" | cut -d: -f6)
    reseed_this=$RESEED
    for r in "${RESEED_USERS[@]}"; do [ "$r" = "$u" ] && reseed_this=1; done
    if [ "$reseed_this" -eq 1 ] || [ ! -f "$home/.log/app.log" ] || [ ! -f "$home/.config/app/config.json" ]; then
        if init_user "$u"; then ok "$u 初始化完成"; else fail=$((fail + 1)); fi
    else
        loginctl enable-linger "$u"
        [ -f "$LESSON_DIR/$u" ] || date +%s > "$LESSON_DIR/$u"
        ok "$u 已有預置檔，略過（要重來請加 --reseed）"
    fi
done
[ "$fail" -eq 0 ] || die "$fail 個帳號初始化失敗，請看上面的訊息"

# ------------------------------------------------------------------ challange 闖關
# 每人一份 ~/.challange（README.txt、decoder.sh）與答案。evil-killer 先停著，sudo lab --start 才啟動。
say "challange 闖關檔案"
for i in $(seq 1 "$LAB_COUNT"); do
    u=$(student_name "$i")
    home=$(getent passwd "$u" | cut -d: -f6)
    if [ "$RESEED" -eq 1 ] || [ ! -f "$home/.challange/decoder.sh" ] \
       || [ ! -f "/var/lib/lab/answers/$u.json" ] || [ ! -f "/var/lib/lab/users/$u.json" ]; then
        user_systemctl "$u" disable --now evil-killer.service >/dev/null 2>&1 || true
        user_systemctl "$u" reset-failed evil-killer.service >/dev/null 2>&1 || true
        /opt/lab/admin/lab-challange build --force "$u" >/dev/null || { fail=$((fail + 1)); warn "$u 的 challange 產生失敗"; continue; }
        ok "$u 的 ~/.challange 已產生"
    else
        ok "$u 已有 ~/.challange，略過（要重來請加 --reseed，或 lab --reset $u）"
    fi
done
[ "$fail" -eq 0 ] || die "$fail 個帳號的 challange 產生失敗，請看上面的訊息"

say "完成"
cat <<EOF
    學員帳號：$(student_name 1) … $(student_name "$LAB_COUNT")
    密碼名單：$LAB_ROSTER
    驗證：    $HERE/verify.sh
    手動測試：ssh $(student_name 1)@<CT 的 IP>
    計分板：  sudo lab --watch（自動更新，Ctrl+C 離開）
    闖關開始：sudo lab --start    下課：sudo lab --stop
EOF
