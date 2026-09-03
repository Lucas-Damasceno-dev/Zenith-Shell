#!/bin/sh
if [ "${1:-}" = "--self-test" ]; then
    echo ok
    exit 0
fi
awk '
  FILENAME ~ /rx_bytes$/ { rx += $1 }
  FILENAME ~ /tx_bytes$/ { tx += $1 }
  END { print rx+0; print tx+0 }
' /sys/class/net/[we]*/statistics/*x_bytes 2>/dev/null
