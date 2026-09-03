from __future__ import annotations

import sys
from typing import Any


def unwrap(value: Any) -> Any:
    if hasattr(value, "value"):
        return unwrap(getattr(value, "value"))
    if isinstance(value, dict):
        return {k: unwrap(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [unwrap(v) for v in value]
    return value


def as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def decode_ssid(raw: Any) -> str:
    value = unwrap(raw)
    if isinstance(value, (bytes, bytearray)):
        return value.decode("utf-8", errors="ignore").strip()
    if isinstance(value, list):
        try:
            return bytes(int(x) & 0xFF for x in value).decode("utf-8", errors="ignore").strip()
        except Exception:
            return ""
    return str(value).strip() if value is not None else ""


def nm_security_text(ap: dict[str, Any]) -> str:
    flags = as_int(ap.get("Flags"), 0)
    wpa = as_int(ap.get("WpaFlags"), 0)
    rsn = as_int(ap.get("RsnFlags"), 0)
    if wpa > 0 and rsn > 0:
        return "WPA/WPA2"
    if rsn > 0:
        return "WPA2"
    if wpa > 0:
        return "WPA"
    if flags & 0x1:
        return "WEP"
    return "--"


def format_band(raw_mhz: Any) -> str:
    mhz = as_int(raw_mhz, 0)
    if 2400 <= mhz <= 2500:
        return "2.4G"
    if 4900 <= mhz <= 5900:
        return "5G"
    if 5925 <= mhz <= 7200:
        return "6G"
    return ""


def format_link_speed(raw_kbit: Any) -> str:
    kbit = as_int(raw_kbit, 0)
    if kbit <= 0:
        return ""
    mbit = kbit / 1000.0
    if mbit >= 1000:
        return f"{mbit / 1000.0:.1f} Gb/s"
    return f"{mbit:.0f} Mb/s"


def u32_to_ipv4(value: Any) -> str:
    try:
        n = int(value) & 0xFFFFFFFF
        return ".".join(str((n >> shift) & 0xFF) for shift in (24, 16, 8, 0))
    except (TypeError, ValueError):
        return ""


def extract_ip4(ip4_props: dict[str, Any]) -> tuple[str, str, list[str]]:
    local_ip = ""
    gateway = str(ip4_props.get("Gateway", "") or "").strip()
    dns_list: list[str] = []

    address_data = ip4_props.get("AddressData")
    if isinstance(address_data, list):
        for item in address_data:
            if isinstance(item, dict):
                addr = str(item.get("address", "") or "").strip()
                if addr:
                    local_ip = addr
                    break

    nameserver_data = ip4_props.get("NameserverData")
    if isinstance(nameserver_data, list):
        for item in nameserver_data:
            if isinstance(item, dict):
                addr = str(item.get("address", "") or "").strip()
                if addr:
                    dns_list.append(addr)

    if not dns_list:
        nameservers = ip4_props.get("Nameservers")
        if isinstance(nameservers, list):
            for raw in nameservers:
                text = u32_to_ipv4(raw)
                if text:
                    dns_list.append(text)

    uniq_dns: list[str] = []
    seen = set()
    for addr in dns_list:
        if addr in seen:
            continue
        seen.add(addr)
        uniq_dns.append(addr)

    return local_ip, gateway, uniq_dns


def build_nm_state(managed_raw: Any) -> dict[str, Any]:
    managed = unwrap(managed_raw)
    if not isinstance(managed, dict):
        managed = {}

    wifi_state = {
        "enabled": False,
        "connected": False,
        "ssid": "",
        "signal": 0,
        "networks": [],
        "ethernet_connected": False,
        "ethernet_name": "",
        "local_ip": "",
        "gateway": "",
        "dns": [],
        "dns_text": "",
        "link_speed": "",
    }
    vpn_state = {"active": False, "name": ""}

    manager_props: dict[str, Any] = {}
    for _path, ifaces in managed.items():
        if not isinstance(ifaces, dict):
            continue
        props = ifaces.get("org.freedesktop.NetworkManager")
        if isinstance(props, dict):
            manager_props = props
            break

    wifi_state["enabled"] = bool(manager_props.get("WirelessEnabled", False))

    selected_ip4_path = ""
    selected_wireless_props: dict[str, Any] | None = None

    active_connections = manager_props.get("ActiveConnections")
    if isinstance(active_connections, list):
        for ac_path in active_connections:
            conn_ifaces = managed.get(str(ac_path), {})
            if not isinstance(conn_ifaces, dict):
                continue
            active_props = conn_ifaces.get("org.freedesktop.NetworkManager.Connection.Active")
            if not isinstance(active_props, dict):
                continue
            ctype = str(active_props.get("Type", "") or "").strip().lower()
            state = as_int(active_props.get("State"), 0)
            if ctype in {"vpn", "wireguard"} and state == 2:
                vpn_state["active"] = True
                vpn_state["name"] = str(active_props.get("Id", "") or "").strip()
            elif ctype in {"802-3-ethernet", "ethernet"} and state == 2:
                wifi_state["ethernet_connected"] = True
                wifi_state["ethernet_name"] = str(active_props.get("Id", "") or "").strip() or "Ethernet"
                ac_ip4 = str(active_props.get("Ip4Config", "") or "")
                if ac_ip4 and not selected_ip4_path:
                    selected_ip4_path = ac_ip4

    networks_by_ssid: dict[str, dict[str, Any]] = {}

    for _path, ifaces in managed.items():
        if not isinstance(ifaces, dict):
            continue

        dprops = ifaces.get("org.freedesktop.NetworkManager.Device")
        if isinstance(dprops, dict):
            dev_type = as_int(dprops.get("DeviceType"), 0)
            dev_state = as_int(dprops.get("State"), 0)
            if dev_type == 1 and dev_state == 100:
                wifi_state["ethernet_connected"] = True
                if not selected_ip4_path:
                    selected_ip4_path = str(dprops.get("Ip4Config", "") or "")

        wprops = ifaces.get("org.freedesktop.NetworkManager.Device.Wireless")
        if not isinstance(wprops, dict):
            continue

        if not isinstance(dprops, dict):
            dprops = {}

        active_ap = str(wprops.get("ActiveAccessPoint", "") or "")
        if active_ap and active_ap != "/":
            selected_ip4_path = str(dprops.get("Ip4Config", "") or selected_ip4_path)
            selected_wireless_props = wprops
        elif not selected_ip4_path:
            selected_ip4_path = str(dprops.get("Ip4Config", "") or "")
            selected_wireless_props = selected_wireless_props or wprops

        ap_paths = wprops.get("AccessPoints")
        if not isinstance(ap_paths, list):
            continue

        for ap_path in ap_paths:
            ap_ifaces = managed.get(str(ap_path), {})
            if not isinstance(ap_ifaces, dict):
                continue
            ap_props = ap_ifaces.get("org.freedesktop.NetworkManager.AccessPoint")
            if not isinstance(ap_props, dict):
                continue

            ssid = decode_ssid(ap_props.get("Ssid"))
            if ssid == "":
                continue

            signal = max(0, min(100, as_int(ap_props.get("Strength"), 0)))
            security = nm_security_text(ap_props)
            active = str(ap_path) == active_ap

            freq = as_int(ap_props.get("Frequency"), 0)
            band = format_band(freq)

            current = networks_by_ssid.get(ssid)
            candidate = {
                "ssid": ssid,
                "signal": signal,
                "active": active,
                "security": security,
                "frequency": freq,
                "band": band,
            }
            if current is None:
                networks_by_ssid[ssid] = candidate
            else:
                if candidate["active"] and not current["active"]:
                    networks_by_ssid[ssid] = candidate
                elif candidate["signal"] > current["signal"]:
                    merged = candidate
                    if current["active"]:
                        merged["active"] = True
                    networks_by_ssid[ssid] = merged

    networks = list(networks_by_ssid.values())
    networks.sort(key=lambda item: (0 if item.get("active") else 1, -int(item.get("signal", 0)), str(item.get("ssid", "")).lower()))
    wifi_state["networks"] = networks

    for network in networks:
        if network.get("active"):
            wifi_state["connected"] = True
            wifi_state["ssid"] = str(network.get("ssid", ""))
            wifi_state["signal"] = as_int(network.get("signal"), 0)
            break

    if selected_wireless_props is not None:
        wifi_state["link_speed"] = format_link_speed(selected_wireless_props.get("Bitrate"))

    if selected_ip4_path and selected_ip4_path != "/":
        ip_ifaces = managed.get(selected_ip4_path, {})
        if isinstance(ip_ifaces, dict):
            ip4_props = ip_ifaces.get("org.freedesktop.NetworkManager.IP4Config")
            if isinstance(ip4_props, dict):
                local_ip, gateway, dns_list = extract_ip4(ip4_props)
                wifi_state["local_ip"] = local_ip
                wifi_state["gateway"] = gateway
                wifi_state["dns"] = dns_list
                wifi_state["dns_text"] = ", ".join(dns_list)

    return {"wifi": wifi_state, "vpn": vpn_state}


def build_bluez_state(managed_raw: Any) -> dict[str, Any]:
    managed = unwrap(managed_raw)
    if not isinstance(managed, dict):
        managed = {}

    state = {
        "enabled": False,
        "pairable": False,
        "discoverable": False,
        "scanning": False,
        "devices": [],
    }

    for _path, ifaces in managed.items():
        if not isinstance(ifaces, dict):
            continue
        adapter = ifaces.get("org.bluez.Adapter1")
        if not isinstance(adapter, dict):
            continue
        state["enabled"] = bool(adapter.get("Powered", False))
        state["pairable"] = bool(adapter.get("Pairable", False))
        state["discoverable"] = bool(adapter.get("Discoverable", False))
        state["scanning"] = bool(adapter.get("Discovering", False))
        break

    devices: list[dict[str, Any]] = []
    for _path, ifaces in managed.items():
        if not isinstance(ifaces, dict):
            continue
        dev = ifaces.get("org.bluez.Device1")
        if not isinstance(dev, dict):
            continue

        mac = str(dev.get("Address", "") or "").strip()
        if mac == "":
            continue

        name = str(dev.get("Alias") or dev.get("Name") or mac).strip() or mac
        paired = bool(dev.get("Paired", False))
        connected = bool(dev.get("Connected", False))
        icon = str(dev.get("Icon", "") or "").strip()

        battery_text = ""
        bat = ifaces.get("org.bluez.Battery1")
        if isinstance(bat, dict):
            raw_percentage = bat.get("Percentage")
            if isinstance(raw_percentage, (int, float)):
                battery_text = f"{int(round(float(raw_percentage)))}%"

        devices.append({
            "mac": mac,
            "name": name,
            "paired": paired,
            "connected": connected,
            "icon": icon,
            "battery": battery_text,
        })

    devices.sort(key=lambda d: (0 if d.get("connected") else 1, 0 if d.get("paired") else 1, str(d.get("name", "")).lower()))
    state["devices"] = devices
    return state


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "--self-test":
    print("ok")
    raise SystemExit(0)
