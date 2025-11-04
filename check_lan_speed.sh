#!/bin/bash
# -----------------------------------------
# Проверка скорости 2.5G LAN (lan1)
# Перезапуск интерфейса при падении ниже 2.5G
# и уведомление в Telegram
# -----------------------------------------

export PATH=/usr/sbin:/usr/bin:/sbin:/bin

LAN_IF="lan1"       # физический порт 2.5G
LOG_IF="lan"        # логический интерфейс
LOGFILE="/tmp/lan_speed_monitor.log"
STATE_FILE="/tmp/lan_speed_state"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# --- Telegram настройки ---
TG_TOKEN="XXXXXXX"
CHAT_ID="XXXXXXX"

send_telegram() {
    local MSG="$1"
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
         -d chat_id="${CHAT_ID}" \
         -d text="$MSG" >/dev/null 2>&1
}

# --- Проверка скорости ---
SPEED_LINE=$(/usr/sbin/ethtool "$LAN_IF" 2>/dev/null | grep "Speed:")
SPEED=$(echo "$SPEED_LINE" | grep -oE '[0-9]+')

if [[ -z "$SPEED" ]]; then
    echo "[$DATE] ERROR: Не удалось получить скорость интерфейса $LAN_IF" >> "$LOGFILE"
    exit 1
fi

LAST_SPEED=$(cat "$STATE_FILE" 2>/dev/null || echo "2500")

UBUS_PATH=$(command -v ubus 2>/dev/null)
if [[ -z "$UBUS_PATH" ]]; then
    echo "[$DATE] ERROR: Не найден ubus, не могу перезапустить интерфейс $LOG_IF" >> "$LOGFILE"
    exit 1
fi

if [[ "$SPEED" -lt 2500 ]]; then
    if [[ "$LAST_SPEED" -lt 2500 ]]; then
        MSG="⚠️ Flint-2: скорость ${LAN_IF} упала до ${SPEED}Mb/s. Перезапуск интерфейса ${LOG_IF}..."
        echo "[$DATE] WARNING: $MSG" >> "$LOGFILE"
        send_telegram "$MSG"

        "$UBUS_PATH" call network.interface.$LOG_IF down
        sleep 2
        "$UBUS_PATH" call network.interface.$LOG_IF up

        echo "[$DATE] INFO: Интерфейс ${LOG_IF} перезапущен." >> "$LOGFILE"
        send_telegram "✅ Интерфейс ${LOG_IF} успешно перезапущен."
    else
        echo "[$DATE] WARNING: Скорость ${LAN_IF} = ${SPEED}Mb/s (первая проверка ниже нормы)." >> "$LOGFILE"
    fi
else
    echo "[$DATE] OK: Скорость ${LAN_IF} = ${SPEED}Mb/s." >> "$LOGFILE"
fi

echo "$SPEED" > "$STATE_FILE"
