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

if [[ "${1:-}" == "--self-test" ]]; then
    command -v lsblk >/dev/null 2>&1 || exit 1
    command -v jq >/dev/null 2>&1 || exit 1
    command -v udisksctl >/dev/null 2>&1 || exit 1
    echo ok
    exit 0
fi

# List USB / Removable block devices in normalized JSON format
list_devices() {
    local raw_json
    raw_json=$(lsblk -J -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL,HOTPLUG,TRAN,MODEL,FSTYPE,FSAVAIL,FSUSED,FSUSE%,RM 2>/dev/null || echo '{"blockdevices":[]}')
    
    echo "$raw_json" | jq -c '
      [
        .blockdevices[]? |
        select(
          ((.hotplug == true or .tran == "usb" or .rm == true) and 
           (.name | startswith("loop") | not) and 
           (.name | startswith("zram") | not))
        ) |
        if (.children and (.children | length > 0)) then
          . as $parent |
          .children[] | select(.type == "part" or .type == "crypt" or .type == "disk") |
          {
            name: .name,
            parentDisk: $parent.name,
            label: ((.label // $parent.model // .name) | tostring),
            model: (($parent.model // .label // $parent.name) | tostring),
            size: (.size // ""),
            type: .type,
            fstype: (.fstype // ""),
            mountpoint: .mountpoint,
            mounted: (.mountpoint != null and .mountpoint != ""),
            fsused: (.fsused // ""),
            fsavail: (.fsavail // ""),
            fsusepct: (."fsuse%" // "")
          }
        else
          {
            name: .name,
            parentDisk: .name,
            label: ((.label // .model // .name) | tostring),
            model: ((.model // .label // .name) | tostring),
            size: (.size // ""),
            type: .type,
            fstype: (.fstype // ""),
            mountpoint: .mountpoint,
            mounted: (.mountpoint != null and .mountpoint != ""),
            fsused: (.fsused // ""),
            fsavail: (.fsavail // ""),
            fsusepct: (."fsuse%" // "")
          }
        end
      ] | unique_by(.name)
    ' 2>/dev/null || echo '[]'
}

# Mount device
mount_device() {
    local dev="${1:-}"
    if [[ -z "$dev" ]]; then
        echo "Missing device name" >&2
        exit 1
    fi
    udisksctl mount -b "/dev/$dev" 2>&1
}

# Unmount device
unmount_device() {
    local dev="${1:-}"
    if [[ -z "$dev" ]]; then
        echo "Missing device name" >&2
        exit 1
    fi
    udisksctl unmount -b "/dev/$dev" 2>&1
}

# Eject device and power off drive
eject_device() {
    local dev="${1:-}"
    if [[ -z "$dev" ]]; then
        echo "Missing device name" >&2
        exit 1
    fi
    
    # Resolve parent disk
    local parent_disk="$dev"
    if [[ "$dev" =~ ^nvme[0-9]+n[0-9]+p[0-9]+$ || "$dev" =~ ^mmcblk[0-9]+p[0-9]+$ ]]; then
        parent_disk="${dev%p[0-9]*}"
    elif [[ "$dev" =~ [0-9]+$ ]]; then
        parent_disk="${dev%%[0-9]*}"
    fi

    # Unmount partitions and power off
    sync || true
    udisksctl unmount -b "/dev/$dev" 2>/dev/null || true
    
    if [[ "$parent_disk" != "$dev" ]]; then
        for part in /dev/"$parent_disk"[0-9]* /dev/"$parent_disk"p[0-9]*; do
            if [[ -e "$part" && "$part" != "/dev/$dev" ]]; then
                udisksctl unmount -b "$part" 2>/dev/null || true
            fi
        done
    fi

    if udisksctl power-off -b "/dev/$parent_disk" 2>&1; then
        echo "SUCCESS"
    else
        # If power-off fails (e.g. some virtual/MMC media), try eject
        if udisksctl eject -b "/dev/$parent_disk" 2>&1; then
            echo "SUCCESS"
        else
            echo "EJECT_FAILED"
            exit 1
        fi
    fi
}

case "${1:-}" in
    --mount)
        mount_device "${2:-}"
        ;;
    --unmount)
        unmount_device "${2:-}"
        ;;
    --eject)
        eject_device "${2:-}"
        ;;
    --json|"")
        list_devices
        ;;
    *)
        echo "Usage: $0 [--json|--mount <dev>|--unmount <dev>|--eject <dev>|--self-test]" >&2
        exit 1
        ;;
esac
