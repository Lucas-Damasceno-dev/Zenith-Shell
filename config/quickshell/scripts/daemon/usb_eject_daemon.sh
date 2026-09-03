#!/usr/bin/env bash
set -euo pipefail

# Ensure standard paths are available
if [[ -d "/run/current-system/sw/bin" ]]; then
  if [[ -n "${PATH:-}" ]]; then
    export PATH="${PATH}:/run/current-system/sw/bin"
  else
    export PATH="/run/current-system/sw/bin"
  fi
fi

# ── Graceful shutdown on SIGTERM/SIGINT ──────────────────────────────────────
cleanup() {
    jobs -p | xargs -r kill 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

if [[ "${1:-}" == "--self-test" ]]; then
    command -v udevadm >/dev/null 2>&1 || { echo "missing udevadm"; exit 1; }
    command -v lsblk >/dev/null 2>&1 || { echo "missing lsblk"; exit 1; }
    command -v notify-send >/dev/null 2>&1 || { echo "missing notify-send"; exit 1; }
    command -v udisksctl >/dev/null 2>&1 || { echo "missing udisksctl"; exit 1; }
    echo "ok"
    exit 0
fi

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USB_HELPER="$SCRIPT_DIR/../system/usb_devices.sh"

# Run udevadm monitor and notify on removable block devices
udevadm monitor --udev --subsystem-match=block | while read -r line; do
    if [[ "$line" == *" add "* && "$line" == *"/block/"* ]]; then
        dev_name=$(echo "$line" | sed -n 's/.*\/block\/\([a-zA-Z0-9_]*\).*/\1/p' | head -n 1)
        if [[ -z "$dev_name" ]]; then
            continue
        fi

        # Filter out loop / zram / internal virtual devices
        if [[ "$dev_name" =~ ^loop || "$dev_name" =~ ^zram || "$dev_name" =~ ^dm- ]]; then
            continue
        fi

        # Give udev/kernel a moment to populate partitions & sysfs
        sleep 1.2

        # Check if device is USB or removable
        tran=$(lsblk -dno TRAN "/dev/$dev_name" 2>/dev/null || true)
        rm_flag=$(lsblk -dno RM "/dev/$dev_name" 2>/dev/null || true)
        hotplug=$(lsblk -dno HOTPLUG "/dev/$dev_name" 2>/dev/null || true)

        if [[ "$tran" == "usb" || "$rm_flag" == "1" || "$hotplug" == "1" ]]; then
            model=$(lsblk -dno MODEL "/dev/$dev_name" 2>/dev/null | xargs || true)
            size=$(lsblk -dno SIZE "/dev/$dev_name" 2>/dev/null | xargs || true)
            [[ -z "$model" ]] && model="Dispositivo USB"

            (
                action=$(notify-send "USB Conectado: $model ($size)" "Dispositivo pronto para uso." \
                    -i drive-removable-media \
                    -a "Quickshell USB" \
                    -t 8000 \
                    --action="eject=Ejetar $model" 2>/dev/null || true)

                if [[ "$action" == "eject" ]]; then
                    if [[ -x "$USB_HELPER" ]]; then
                        "$USB_HELPER" --eject "$dev_name" >/dev/null 2>&1 || true
                    else
                        sync
                        for part in /dev/"$dev_name"[0-9]* /dev/"$dev_name"p[0-9]* /dev/"$dev_name"; do
                            [[ -e "$part" ]] && udisksctl unmount -b "$part" 2>/dev/null || true
                        done
                        udisksctl power-off -b "/dev/$dev_name" 2>/dev/null || true
                    fi
                    notify-send "USB Ejetado" "$model pode ser removido com segurança." -i emblem-default -t 3000 -a "Quickshell USB" 2>/dev/null || true
                fi
            ) &
        fi
    fi
done &

wait
