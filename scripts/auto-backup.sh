#!/bin/bash
# ==============================================================
# Podman Backup Script with Daily/Weekly/Monthly Rotation
#
# Features:
# 1. Stops all Rootless Podman / Quadlet services for a user
# 2. Stops system-wide podman.service (if running)
# 3. Performs Daily/Weekly/Monthly backups
#    - Daily: incremental rsync (max 7 backups)
#    - Weekly: Full Backup from SRC_DIR, max 1, timestamped
#    - Monthly: Full Backup from SRC_DIR, max 1, timestamped
# 4 Backup size reporting (safe even if dirs empty)
# 5. Backup rotation and log rotation (>5 MB)
# 6. Status reporting for each step (✅ / ❌)
# 7. Rsync progress display
#
# Usage:
# sudo /mnt/podman/backup/auto-backup.sh
#
# Cronjob Example:
# ==========================
# sudo crontab -e
# # Daily backup at 3:00 AM
# 0 3 * * * root /mnt/podman/backup/auto-backup.sh
#
# # The script automatically decides backup type:
# # Daily: runs every day
# # Weekly: runs on Sunday (day 7)
# # Monthly: runs on last day of the month (detected automatically)
# ==========================
# ==============================================================

# -----------------------------
# CONFIGURATION
# -----------------------------
USER_NAME="test"                     # User running Rootless Podman
LOGFILE="/mnt/podman/backup/backup.log"
MAX_LOG_SIZE=$((5*1024*1024))         # Log rotation threshold (5 MB)
SRC_DIR="/mnt/podman/data"            # Source directory to backup
BASE_DEST_DIR="/mnt/podman/backup"    # Backup goes to the separate mounted SSD, HDD or ...
DAILY_DIR="$BASE_DEST_DIR/daily"
WEEKLY_DIR="$BASE_DEST_DIR/weekly"
MONTHLY_DIR="$BASE_DEST_DIR/monthly"

# -----------------------------
# Determine backup type automatically
# Daily: default
# Weekly: every Sunday (day 7)
# Monthly: if tomorrow is the 1st of the month
# -----------------------------
BACKUP_TYPE="daily"
if [ "$(date +%u)" -eq 7 ]; then
    BACKUP_TYPE="weekly"
fi
if [ "$(date +%d -d tomorrow)" == "01" ]; then
    BACKUP_TYPE="monthly"
fi

# -----------------------------
# Rotate log if > MAX_LOG_SIZE
# -----------------------------
if [ -f "$LOGFILE" ]; then
    LOGSIZE=$(stat -c%s "$LOGFILE")
    if [ "$LOGSIZE" -ge "$MAX_LOG_SIZE" ]; then
        echo "Log file too large ($LOGSIZE Bytes). Clearing log..." >> "$LOGFILE"
        : > "$LOGFILE"
    fi
fi

echo "=============================="
echo "Backup started: $(date)"
echo "Backup type: $BACKUP_TYPE"
echo "==============================" | tee -a "$LOGFILE"

# -----------------------------
# Stop Podman Rootless User Services
# -----------------------------
SYSTEMCTL_CMD="systemctl --machine=$USER_NAME@.host --user"
SERVICES=$($SYSTEMCTL_CMD list-units --type=service --all \
           | grep -iE "(Rootless Podman|Pod$|podman-)" \
           | awk '{print $1}')
STOPPED_SERVICES=""
if [ ! -z "$SERVICES" ]; then
    echo "Stopping Rootless Podman User Services..." | tee -a "$LOGFILE"
    for svc in $SERVICES; do
        echo "Stopping Service: $svc ..." | tee -a "$LOGFILE"
        $SYSTEMCTL_CMD stop "$svc"
        STOPPED_SERVICES="$STOPPED_SERVICES $svc"
        if [ $? -eq 0 ]; then
            echo "✅ $svc stopped successfully" | tee -a "$LOGFILE"
        else
            echo "❌ Failed to stop $svc" | tee -a "$LOGFILE"
        fi
    done
else
    echo "No Podman/Quadlet User Services found." | tee -a "$LOGFILE"
fi

# -----------------------------
# Stop system-wide Podman daemon (if running)
# -----------------------------
if systemctl is-active --quiet podman.service; then
    echo "Stopping podman.service ..." | tee -a "$LOGFILE"
    systemctl stop podman.service
    echo "✅ podman.service stopped" | tee -a "$LOGFILE"
fi

# -----------------------------
# Perform Backup
# -----------------------------
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

case "$BACKUP_TYPE" in
  daily)
    mkdir -p "$DAILY_DIR"
    DAILY_TARGET="$DAILY_DIR/daily_$TIMESTAMP"
    echo "Starting Daily Backup (incremental rsync, max 7 days)..." | tee -a "$LOGFILE"
    rsync -a --delete --info=progress2 "$SRC_DIR/" "$DAILY_TARGET/" 2>&1 | tee >(cat >&2) >> "$LOGFILE"
    if [ $? -eq 0 ]; then
        echo "✅ Daily Backup completed: $DAILY_TARGET" | tee -a "$LOGFILE"
    else
        echo "❌ Daily Backup failed" | tee -a "$LOGFILE"
    fi
    ;;
  weekly)
    mkdir -p "$WEEKLY_DIR"
    WEEKLY_TARGET="$WEEKLY_DIR/weekly_$TIMESTAMP"
    echo "Starting Weekly Full Backup from SRC_DIR (tar + zstd)..." | tee -a "$LOGFILE"
    tar --zstd -cvf "$WEEKLY_TARGET.tar.zst" -C "$(dirname "$SRC_DIR")" "$(basename "$SRC_DIR")" 2> >(tee -a "$LOGFILE" >&2)
    if [ $? -eq 0 ]; then
        echo "✅ Weekly Full Backup completed: $WEEKLY_TARGET.tar.zst" | tee -a "$LOGFILE"
    else
        echo "❌ Weekly Backup failed" | tee -a "$LOGFILE"
    fi
    ;;
  monthly)
    mkdir -p "$MONTHLY_DIR"
    MONTHLY_FILE="$MONTHLY_DIR/monthly_$TIMESTAMP.tar.zst"
    echo "Starting Monthly Full Backup from SRC_DIR (tar + zstd)..." | tee -a "$LOGFILE"
    tar --zstd -cvf "$MONTHLY_FILE" -C "$(dirname "$SRC_DIR")" "$(basename "$SRC_DIR")" 2> >(tee -a "$LOGFILE" >&2)
    if [ $? -eq 0 ]; then
        echo "✅ Monthly Full Backup completed: $MONTHLY_FILE" | tee -a "$LOGFILE"
    else
        echo "❌ Monthly Backup failed" | tee -a "$LOGFILE"
    fi
    ;;
esac

# -----------------------------
# Backup Rotation
# -----------------------------
rotate_backups() {
    local dir="$1"
    local max="$2"
    local backups=($(ls -1 "$dir" 2>/dev/null | sort))
    local count=${#backups[@]}

    if [ $count -le $max ]; then
        return 0
    fi

    local to_delete=$((count - max))
    echo "Deleting $to_delete old backup(s) from $dir..." | tee -a "$LOGFILE"

    for ((i=0; i<to_delete; i++)); do
        local target="$dir/${backups[$i]}"
        rm -rf "$target"
        if [ $? -eq 0 ]; then
            echo "🗑️  Deleted old backup: $target" | tee -a "$LOGFILE"
        else
            echo "❌ Failed to delete: $target" | tee -a "$LOGFILE"
        fi
    done
}

# Rotate backups according to type
case "$BACKUP_TYPE" in
  daily) rotate_backups "$DAILY_DIR" 7 ;;
  weekly) rotate_backups "$WEEKLY_DIR" 1 ;;
  monthly) rotate_backups "$MONTHLY_DIR" 1 ;;
esac

# -----------------------------
# Show Backup Sizes (safe if dirs empty)
# -----------------------------
echo "Backup sizes:" | tee -a "$LOGFILE"
show_backup_size() {
    local dir="$1"
    if [ -d "$dir" ]; then
        local files=("$dir"/*)
        if [ -e "${files[0]}" ]; then
            du -sh "$dir"/* 2>/dev/null | tee -a "$LOGFILE"
        else
            echo "No backups in $dir" | tee -a "$LOGFILE"
        fi
    else
        echo "Directory $dir does not exist" | tee -a "$LOGFILE"
    fi
}

show_backup_size "$DAILY_DIR"
show_backup_size "$WEEKLY_DIR"
show_backup_size "$MONTHLY_DIR"

# -----------------------------
# Restart Podman daemon
# -----------------------------
if systemctl list-unit-files | grep -q podman.service; then
    systemctl start podman.service
    echo "✅ podman.service started" | tee -a "$LOGFILE"
fi

# -----------------------------
# Restart Rootless User Services
# -----------------------------
if [ ! -z "$STOPPED_SERVICES" ]; then
    for svc in $STOPPED_SERVICES; do
        echo "Starting Service: $svc ..." | tee -a "$LOGFILE"
        $SYSTEMCTL_CMD start "$svc"
        if [ $? -eq 0 ]; then
            echo "✅ $svc started successfully" | tee -a "$LOGFILE"
        else
            echo "❌ Failed to start $svc" | tee -a "$LOGFILE"
        fi
    done
fi

echo "=============================="
echo "Backup finished: $(date)"
echo "==============================" | tee -a "$LOGFILE"

exit 0
