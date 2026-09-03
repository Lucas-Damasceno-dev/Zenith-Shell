#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess

home = os.path.expanduser("~")
repo_cheats_dir = os.path.join(home, ".config/quickshell/cheatsheets")
categories = ("hyprland", "neovim", "tmux", "nixos", "cli", "opencode", "quickshell")


def split_mod_key(cmd):
    mod = ""
    key = cmd
    if " + " in cmd:
        split = cmd.rsplit(" + ", 1)
        mod = split[0].strip()
        key = split[1].strip()
    return mod, key


def add_entry(entries, seen, category, mod, key, action):
    mod = str(mod or "").strip()
    key = str(key or "").strip()
    action = str(action or "").strip()
    if key == "" or action == "":
        return

    signature = (mod.lower(), key.lower(), action.lower())
    if signature in seen:
        return

    seen.add(signature)
    entries.append(
        {
            "mod": mod,
            "key": key,
            "action": action,
        }
    )


def parse_md(filepath, category, entries, seen):
    if not os.path.exists(filepath):
        return

    with open(filepath, "r", encoding="utf-8") as handle:
        lines = handle.readlines()

    current_context = ""
    for line in lines:
        if line.startswith("## "):
            current_context = line[3:].strip()
            continue

        stripped = line.strip()
        if stripped == "" or stripped == "---":
            continue

        if stripped.startswith("|") and "---" not in stripped:
            parts = [part.strip() for part in stripped.split("|") if part.strip() != ""]
            if len(parts) >= 2:
                cmd = parts[0].replace("`", "").strip()
                if cmd.lower() in [
                    "comando",
                    "tecla",
                    "atalho",
                    "command",
                    "key",
                    "alias",
                ]:
                    continue
                action = parts[1].strip()
                action = action.replace("`", "")
                extra = " | ".join([part for part in parts[2:] if part])
                if extra:
                    extra = extra.replace("`", "")
                    action += f"  —  {extra}"

                mod, key = split_mod_key(cmd)
                if current_context:
                    action = f"[{current_context}] {action}"
                add_entry(entries, seen, category, mod, key, action)
            continue

        bullet_match = re.match(r"^\s*(?:[-*+]|\d+\.)\s+(.+)$", line)
        if not bullet_match:
            continue

        content = bullet_match.group(1).strip()
        if content == "":
            continue

        key = ""
        action = ""
        mod = ""

        code_matches = re.findall(r"`([^`]+)`", content)
        if code_matches:
            key = code_matches[0].strip()
            action = re.sub(r"`" + re.escape(key) + r"`", "", content, count=1).strip()
            action = action.replace("`", "")
            action = action.replace("**", "").replace("__", "")
            action = re.sub(r"^[\-\–—: ]+", "", action).strip()
        else:
            bold_match = re.match(r"^\*\*([^*]+)\*\*[:\-]?\s*(.+)$", content)
            if bold_match:
                key = bold_match.group(1).strip().rstrip(":")
                action = bold_match.group(2).strip()
            else:
                continue

        if current_context:
            action = f"[{current_context}] {action}"
        add_entry(entries, seen, category, mod, key, action)


def parse_md_candidates(paths, category, entries, seen):
    for path in paths:
        if os.path.exists(path):
            parse_md(path, category, entries, seen)
            return


def parse_md_candidates_skip_pairs(paths, category, entries, seen, skip_pairs):
    for path in paths:
        if not os.path.exists(path):
            continue

        with open(path, "r", encoding="utf-8") as handle:
            lines = handle.readlines()

        current_context = ""
        for line in lines:
            if line.startswith("## "):
                current_context = line[3:].strip()
                continue

            stripped = line.strip()
            if stripped == "" or stripped == "---":
                continue

            if stripped.startswith("|") and "---" not in stripped:
                parts = [
                    part.strip() for part in stripped.split("|") if part.strip() != ""
                ]
                if len(parts) >= 2:
                    cmd = parts[0].replace("`", "").strip()
                    if cmd.lower() in [
                        "comando",
                        "tecla",
                        "atalho",
                        "command",
                        "key",
                        "alias",
                    ]:
                        continue
                    action = parts[1].strip().replace("`", "")
                    extra = " | ".join([part for part in parts[2:] if part])
                    if extra:
                        extra = extra.replace("`", "")
                        action += f"  —  {extra}"

                    mod, key = split_mod_key(cmd)
                    if current_context:
                        action = f"[{current_context}] {action}"

                    if (mod.lower(), key.lower()) in skip_pairs:
                        continue

                    add_entry(entries, seen, category, mod, key, action)
                continue

            bullet_match = re.match(r"^\s*(?:[-*+]|\d+\.)\s+(.+)$", line)
            if not bullet_match:
                continue

            content = bullet_match.group(1).strip()
            if content == "":
                continue

            key = ""
            action = ""
            mod = ""

            code_matches = re.findall(r"`([^`]+)`", content)
            if code_matches:
                key = code_matches[0].strip()
                action = re.sub(
                    r"`" + re.escape(key) + r"`", "", content, count=1
                ).strip()
                action = action.replace("`", "")
                action = action.replace("**", "").replace("__", "")
                action = re.sub(r"^[\-\–—: ]+", "", action).strip()
            else:
                bold_match = re.match(r"^\*\*([^*]+)\*\*[:\-]?\s*(.+)$", content)
                if bold_match:
                    key = bold_match.group(1).strip().rstrip(":")
                    action = bold_match.group(2).strip()
                else:
                    continue

            if current_context:
                action = f"[{current_context}] {action}"

            if (mod.lower(), key.lower()) in skip_pairs:
                continue

            add_entry(entries, seen, category, mod, key, action)


def build_category(category):
    if category not in categories:
        raise SystemExit(f"Unknown cheat sheet category: {category}")

    entries = []
    seen = set()

    if category == "hyprland":
        parse_md_candidates_skip_pairs(
            [
                f"{home}/Documents/cheatSheet/HYPRLAND.md",
                f"{repo_cheats_dir}/HYPRLAND.md",
            ],
            category,
            entries,
            seen,
            set(),
        )

        seen_bind_pairs = set()
        for entry in entries:
            seen_bind_pairs.add(
                (str(entry.get("mod", "")).lower(), str(entry.get("key", "")).lower())
            )

        try:
            hypr_output = subprocess.check_output(["hyprctl", "-j", "binds"], text=True)
            binds = json.loads(hypr_output)
            for bind in binds:
                key = bind.get("key", "")
                dispatcher = bind.get("dispatcher", "")
                if not key or not dispatcher:
                    continue

                mods = []
                modmask = int(bind.get("modmask", 0) or 0)
                if modmask & 64:
                    mods.append("SUPER")
                if modmask & 8:
                    mods.append("ALT")
                if modmask & 4:
                    mods.append("CTRL")
                if modmask & 1:
                    mods.append("SHIFT")

                mod_str = " + ".join(mods)
                action = dispatcher
                arg = bind.get("arg", "")
                if arg:
                    action += f" {arg}"

                action = action.replace(
                    f"{home}/.config/hypr/scripts/super-combo.sh; ", ""
                )
                action = action.replace(f"{home}/.config/hypr/scripts/", "")
                action = action.replace("quickshell ipc call ipcHandler ", "QS: ")

                if (mod_str.lower(), key.lower()) in seen_bind_pairs:
                    continue

                add_entry(entries, seen, category, mod_str, key, action)
                seen_bind_pairs.add((mod_str.lower(), key.lower()))
        except Exception as exc:
            add_entry(entries, seen, category, "ERR", "hyprctl binds", str(exc))
    elif category == "neovim":
        parse_md_candidates(
            [
                f"{repo_cheats_dir}/NEOVIM.md",
                f"{repo_cheats_dir}/NEOVIM_CHEATSHEET.md",
                f"{home}/Documents/cheatSheet/NEOVIM.md",
            ],
            category,
            entries,
            seen,
        )
    elif category == "tmux":
        parse_md_candidates(
            [
                f"{home}/Documents/cheatSheet/TMUX.md",
                f"{repo_cheats_dir}/TMUX.md",
            ],
            category,
            entries,
            seen,
        )
    elif category == "nixos":
        parse_md_candidates(
            [
                f"{home}/Documents/cheatSheet/NIXOS.md",
                f"{repo_cheats_dir}/NIXOS.md",
            ],
            category,
            entries,
            seen,
        )
    elif category == "cli":
        parse_md_candidates(
            [
                f"{home}/Documents/cheatSheet/CLI.md",
                f"{repo_cheats_dir}/CLI.md",
            ],
            category,
            entries,
            seen,
        )
    elif category == "opencode":
        parse_md_candidates(
            [
                f"{home}/Documents/cheatSheet/OPENCODE.md",
                f"{repo_cheats_dir}/OPENCODE.md",
            ],
            category,
            entries,
            seen,
        )
    elif category == "quickshell":
        parse_md_candidates(
            [
                f"{home}/Documents/cheatSheet/QUICKSHELL.md",
                f"{repo_cheats_dir}/QUICKSHELL.md",
            ],
            category,
            entries,
            seen,
        )

    return entries


def build_all():
    data = {}
    for category in categories:
        data[category] = build_category(category)
    return data


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--category")
    parser.add_argument("--self-test", action="store_true")
    args, _ = parser.parse_known_args()

    if args.self_test:
        entries = build_category("cli")
        if not isinstance(entries, list):
            raise SystemExit("self-test failed")
        print("ok")
        return

    if args.category:
        category = args.category.strip()
        print(
            json.dumps(
                {
                    "category": category,
                    "entries": build_category(category),
                }
            )
        )
        return

    print(json.dumps(build_all()))


if __name__ == "__main__":
    main()
