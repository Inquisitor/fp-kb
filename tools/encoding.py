#!/usr/bin/env python3
"""FP source-file encoding tool: check/fix UTF-8 BOM, CRLF line endings, trailing newline.

The FP server .editorconfig mandates UTF-8 WITH BOM and CRLF for source files; agent
Write/Edit tools produce LF without BOM, so every generated/edited file must be verified.

Usage:
  python encoding.py check <file>...      report per file; exit 1 if any file is not BOM+CRLF+trailing-newline
  python encoding.py fix <file>...        make each file BOM + pure-CRLF + trailing newline (idempotent)
  python encoding.py add-bom <file>...    add the UTF-8 BOM if missing (idempotent)
  python encoding.py strip-bom <file>...  remove the UTF-8 BOM if present (idempotent)
  python encoding.py to-crlf <file>...    normalize all line endings to CRLF (idempotent)

check --no-bom: for files that must NOT carry a BOM (rare; e.g. some JSON tooling) -
report/fail on BOM presence instead.
"""
import sys

BOM = b"\xef\xbb\xbf"


def read(path):
    with open(path, "rb") as f:
        return f.read()


def write(path, data):
    with open(path, "wb") as f:
        f.write(data)


def stats(data):
    body = data[len(BOM):] if data.startswith(BOM) else data
    crlf = body.count(b"\r\n")
    lone_lf = body.count(b"\n") - crlf
    lone_cr = body.count(b"\r") - crlf
    trailing = body.endswith(b"\n")
    return data.startswith(BOM), crlf, lone_lf, lone_cr, trailing


def check(paths, bom_required=True):
    bad = 0
    for p in paths:
        has_bom, crlf, lone_lf, lone_cr, trailing = stats(read(p))
        ok = (has_bom == bom_required) and lone_lf == 0 and lone_cr == 0 and trailing
        bad += 0 if ok else 1
        print("%-4s %s [%s] crlf=%d lf=%d cr=%d %s" % (
            "OK" if ok else "FAIL", p,
            "BOM" if has_bom else "no-BOM", crlf, lone_lf, lone_cr,
            "trailing-nl" if trailing else "NO-trailing-nl"))
    return 1 if bad else 0


def to_crlf_bytes(data):
    has_bom = data.startswith(BOM)
    body = data[len(BOM):] if has_bom else data
    body = body.replace(b"\r\n", b"\n").replace(b"\r", b"\n").replace(b"\n", b"\r\n")
    return (BOM if has_bom else b"") + body


def fix(paths):
    for p in paths:
        data = to_crlf_bytes(read(p))
        if not data.startswith(BOM):
            data = BOM + data
        if not data.endswith(b"\n"):
            data += b"\r\n"
        write(p, data)
        print("fixed %s" % p)
    return 0


def add_bom(paths):
    for p in paths:
        data = read(p)
        if not data.startswith(BOM):
            write(p, BOM + data)
            print("added BOM %s" % p)
        else:
            print("already BOM %s" % p)
    return 0


def strip_bom(paths):
    for p in paths:
        data = read(p)
        if data.startswith(BOM):
            write(p, data[len(BOM):])
            print("stripped BOM %s" % p)
        else:
            print("no BOM %s" % p)
    return 0


def to_crlf(paths):
    for p in paths:
        write(p, to_crlf_bytes(read(p)))
        print("crlf %s" % p)
    return 0


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd, args = argv[1], argv[2:]
    if cmd == "check":
        bom_required = True
        if args and args[0] == "--no-bom":
            bom_required, args = False, args[1:]
        return check(args, bom_required)
    if cmd == "fix":
        return fix(args)
    if cmd == "add-bom":
        return add_bom(args)
    if cmd == "strip-bom":
        return strip_bom(args)
    if cmd == "to-crlf":
        return to_crlf(args)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
