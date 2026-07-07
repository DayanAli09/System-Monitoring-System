#!/bin/bash

# -----------------------------------------
# System Monitoring & Alert System
# Author: Dayan Ali
# Language: Bash
# Features:
# CPU Monitoring
# Memory Monitoring
# Disk Monitoring
# Security Monitoring
# Encrypted Reports
# -----------------------------------------

REPORT_DIR="$HOME/sys_reports"
mkdir -p "$REPORT_DIR"

CPU_THRESHOLD=80
MEM_THRESHOLD=85
DISK_THRESHOLD=90

# ── CPU ──
get_cpu() {
    top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d. -f1
}

# ── Load ──
get_load() {
    awk '{print $1, $2, $3}' /proc/loadavg
}

# ── Memory ──
get_mem() {
    free | awk '/Mem:/ {printf("%d %d %d\n", $3/$2*100, $3/1024, $2/1024)}'
}

# ── Disk ──
get_disk() {
    df / | awk 'NR==2 {gsub("%","",$5); print $5" "$3/1024" "$2/1024}'
}

# ── Network ──
get_net() {
    iface=$(ip route | awk '/default/ {print $5; exit}')
    ip addr show "$iface" | awk '/inet / {print $2}' | head -1
}

# ── Security ──
get_security() {
    USERS=$(who | awk '{print $1}' | sort -u | paste -sd',')

    if command -v ufw &>/dev/null; then
        FIREWALL=$(ufw status | head -1 | awk '{print $2}')
    else
        FIREWALL="not installed"
    fi

    FAILED=$(lastb 2>/dev/null | grep -v "btmp" | wc -l)
}

# ── Top Processes ──
get_top() {
    echo "Top CPU Processes:"
    ps aux --sort=-%cpu | head -6

    echo ""
    echo "Top Memory Processes:"
    ps aux --sort=-%mem | head -6
}

# ── Collect ──
collect() {
    CPU=$(get_cpu)
    read LOAD1 LOAD5 LOAD15 <<< $(get_load)
    read MEM MEM_USED MEM_TOTAL <<< $(get_mem)
    read DISK DISK_USED DISK_TOTAL <<< $(get_disk)
    NET=$(get_net)
    get_security
}

# ── Alerts + Suggestions ──
alerts() {
    echo "---- Alerts & Suggestions ----"

    [[ $CPU -ge $CPU_THRESHOLD ]] && {
        echo "High CPU: $CPU%  →  Kill unused processes: kill <PID>"
    }

    [[ $MEM -ge $MEM_THRESHOLD ]] && {
        echo "High Memory: $MEM%  →  Run: sync; echo 3 > /proc/sys/vm/drop_caches"
    }

    [[ $DISK -ge $DISK_THRESHOLD ]] && {
        echo "Disk Full: $DISK%  →  Run: apt autoremove OR journalctl --vacuum-size=100M"
    }

    if [[ "$FIREWALL" == "inactive" || "$FIREWALL" == "not" ]]; then
        echo "Firewall is inactive  →  Enable: sudo ufw enable"
    fi

    if [[ $FAILED -gt 0 ]]; then
        echo "Failed login attempts detected: $FAILED  →  Check logs: lastb"
    fi

    echo ""
}

# ── Show ──
show() {
    echo "========== SYSTEM HEALTH =========="
    echo "User: $(whoami)"
    echo "Time: $(date)"
    echo ""

    echo "CPU Usage   : $CPU%"
    echo "Load Avg    : $LOAD1 $LOAD5 $LOAD15"
    echo "Memory Usage: $MEM% ($MEM_USED MB / $MEM_TOTAL MB)"
    echo "Disk Usage  : $DISK%"
    echo "Network IP  : $NET"
    echo ""

    echo "---- Security ----"
    echo "Logged Users : $USERS"
    echo "Firewall     : $FIREWALL"
    echo "Failed Logins: $FAILED"
    echo ""

    alerts
    get_top
}

# ── Save Report ──
save_report() {
    FILE="$REPORT_DIR/report_$(date +%Y%m%d_%H%M%S).enc"

    REPORT=$(cat <<EOF
SYSTEM REPORT
User: $(whoami)
Time: $(date)

CPU: $CPU%
Load: $LOAD1 $LOAD5 $LOAD15
Memory: $MEM%
Disk: $DISK%
IP: $NET

SECURITY
Users: $USERS
Firewall: $FIREWALL
Failed logins: $FAILED
EOF
)

    read -sp "Enter password: " PASS; echo ""

    echo "$REPORT" | openssl enc -aes-256-cbc -pbkdf2 \
        -pass pass:"$PASS" -out "$FILE"

    echo "Report saved: $FILE"
}

# ── View Report ──
view_report() {
    read -sp "Enter password: " PASS; echo ""

    openssl enc -d -aes-256-cbc -pbkdf2 \
        -pass pass:"$PASS" -in "$1"
}

# ── Main ──
case "$1" in
    -r|--report)
        collect
        show
        save_report
        ;;
    -v|--view)
        view_report "$2"
        ;;
    *)
        collect
        show
        ;;
esac
