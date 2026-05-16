---
name: ASCII-only in code and commit messages
description: Use ASCII-only characters in source code (comments, docs, strings) and commit messages. Replace Unicode punctuation with ASCII equivalents. KB pages are exempt.
type: feedback
---

Source files and commit messages must use ASCII-only characters. Unicode (em-dashes, arrows, smart quotes,
ellipsis, etc.) is to be avoided except where absolutely necessary — e.g. when the character is the actual
semantic payload (a literal string holding a foreign-language character, an enum value name, etc.).

**Why:** Unicode in code surfaces creates problems for tooling that assumes ASCII (legacy log scrapers,
grep without `-P`, build tools, commit-message linters, terminal diff viewers under non-UTF-8 locale). It
also costs review attention — a stray em-dash flags as a "look-alike" of a hyphen. The project's
`.editorconfig` mandates UTF-8 BOM encoding for storage, but content within files is still expected to be
ASCII.

**Scope:** code (`.cs`, `.cshtml`, `.sql`, `.csproj`, …) and commit messages. **KB pages are exempt** —
they're prose for humans, and showing Unicode in examples (like the table below) is the whole point.

**How to apply:** When writing comments, XML docs, log strings, commit subjects and bodies — use ASCII.
Common substitutions:

| Unicode             | ASCII                       |
|---------------------|-----------------------------|
| `→` (Unicode arrow) | `->`                        |
| `—` (em-dash)       | `--` (double-hyphen) or `-` |
| `…`                 | `...` (three periods)       |
| `“` / `”`           | `"` (ASCII double quote)    |
| `‘` / `’`           | `'` (ASCII apostrophe)      |
| non-breaking space  | regular space               |

UTF-8 BOM at file start is a project-wide convention (`.editorconfig`); keep it. The rule covers content,
not encoding.
