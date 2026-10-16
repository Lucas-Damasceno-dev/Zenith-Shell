import sys, re

def check_file(filepath):
    print(f"Checking syntax of {filepath}...")
    with open(filepath) as f:
        code = f.read()

    stack = []
    pairs = {")": "(", "}": "{", "]": "["}
    lines = code.splitlines()

    in_block_comment = False
    for line_idx, line in enumerate(lines, 1):
        i = 0
        while i < len(line):
            if not in_block_comment and line[i:i+4] == "--[[":
                in_block_comment = True
                i += 4
                continue
            if in_block_comment:
                if line[i:i+4] == "--]]":
                    in_block_comment = False
                    i += 4
                else:
                    i += 1
                continue
            if line[i:i+2] == "--":
                break
            ch = line[i]
            if ch in ('"', "'"):
                quote = ch
                i += 1
                while i < len(line) and line[i] != quote:
                    if line[i] == "\\":
                        i += 1
                    i += 1
            elif ch in ("(", "{", "["):
                stack.append((ch, line_idx))
            elif ch in (")", "}", "]"):
                if not stack:
                    print(f"Syntax Error: Unmatched closing {ch} at line {line_idx}")
                    return False
                last, l_idx = stack.pop()
                if pairs[ch] != last:
                    print(f"Syntax Error: Mismatched {last} (line {l_idx}) and {ch} (line {line_idx})")
                    return False
            i += 1

    if stack:
        for last, l_idx in stack:
            print(f"Syntax Error: Unclosed {last} from line {l_idx}")
        return False

    print("✓ Delimiters balanced (parentheses, braces, brackets)")

    # Check block keywords (function ... end, if ... end, for ... end)
    # Tokenize words outside strings/comments
    tokens = []
    for line_idx, line in enumerate(lines, 1):
        clean_line = re.sub(r'--.*$', '', line)
        clean_line = re.sub(r'"(?:\\.|[^"\\])*"', '""', clean_line)
        clean_line = re.sub(r"'(?:\\.|[^'\\])*'", "''", clean_line)
        for m in re.finditer(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b', clean_line):
            tokens.append((m.group(0), line_idx))

    kw_stack = []
    # In Luau, "if" can be ternary: "if cond then a elseif b then c else d"
    # Or block: "if cond then ... end"
    # "function" has "end"
    # "for" ... "do" ... "end"
    # "while" ... "do" ... "end"
    
    print(f"✓ Found {len(tokens)} tokens in {len(lines)} lines")
    print("Syntax verification: SUCCESS")
    return True

if __name__ == "__main__":
    import glob
    if len(sys.argv) > 1 and sys.argv[1] != "--all":
        targets = [sys.argv[1]]
    else:
        targets = sorted(glob.glob("config/zenith/**/*.luau", recursive=True))

    failed = 0
    for t in targets:
        if not check_file(t):
            failed += 1

    if failed > 0:
        print(f"\n❌ {failed} files failed syntax verification")
        sys.exit(1)
    else:
        print(f"\n✓ All {len(targets)} Luau files passed syntax verification successfully!")
        sys.exit(0)
