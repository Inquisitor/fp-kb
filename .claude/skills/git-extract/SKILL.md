---
name: git-extract
description: >
  Preserve Git history when extracting a section from a file into a new file.
  Use when splitting files, extracting classes/methods, moving documentation sections,
  or collapsing plan subtasks into archived files.
  Triggers: "extract", "вынести в отдельный файл", "разбить файл",
  "split into partial", "collapse subtask".
argument-hint: "[source-file destination-file]"
---

# History-Preserving File Extraction

Extract a section from one file into a new file using a 2-commit technique
so that `git blame -C -C` traces lines back to their original commits.

## When to use
- Extracting a class, methods, or interface into a new file
- Splitting a class into partial files
- Moving a documentation section to its own file
- Collapsing plan subtasks into `archived/subtasks/` files

## When NOT to use
- Simple file rename/move (Git tracks natively with `git mv`)
- Creating entirely new content (no history to preserve)
- SVN repos (use `svn copy` instead)

## Discipline
- Every step in this skill is **mandatory**, not advisory.
- Do NOT skip steps because you think you know the answer (e.g., skipping `AskUserQuestion` because global CLAUDE.md "already covers" commit policy).
- If a step says "Use tool X" — use tool X. No substitutions, no shortcuts.

## Steps

### 0. Pre-flight
- Identify: source file, section(s) to extract, destination path(s)
- Ensure source file has no uncommitted changes (copy must match last commit)
- Ensure destination file does NOT already exist (technique relies on file creation commit; if exists — delete in a prior commit or use a different path)
- Create destination directories if needed (`mkdir -p`)
- Use `AskUserQuestion` to determine commit workflow:
  - **"I'll commit myself"** — agent drafts commit messages, user runs `git commit`
  - **"You commit, I'll review"** — agent drafts message, user edits if needed, agent commits
  - **"You commit, go ahead"** — agent commits autonomously

### 1. Commit: copy source → destination (history anchor)
- Copy the **entire** source file to the destination path(s)
- Stage **only** the new file(s) (do not touch the source yet)
- Commit message: `Extract prep: copy <source> → <dest> (history anchor)`
- **Wait for commit to complete before proceeding**
- Why full copy: `-C -C` searches files in the parent of the commit that **created** the destination. Full copy guarantees every line has an identical counterpart in the source, so blame traces regardless of the 40-char detection threshold

### 2. Edit freely, then commit
- Edit destination: trim to extracted section, adjust as needed (class names, namespaces, headers, any refactoring)
- Edit source: remove the extracted section (or collapse to one-liner with reference)
- Any further edits are fine — blame traces individual lines, so surviving unchanged lines trace back regardless of surrounding changes
- Stage both files (edited source + trimmed destination)
- When ready, commit with descriptive message (e.g., `Extract TRM-003 subtask from alignment plan`)
- **Never squash** commits 1 and 2 together — squashing destroys the history anchor
- After commit, tell the user: `git blame -C -C <destination-file>` to verify history tracing

## Multiple extractions from one file
- Step 1: copy source to ALL destinations in a single commit
- Step 2: edit all files, commit when done

## How it works
- `-C` (single): detects lines moved/copied from files **modified in the same commit** (extends `-M` which detects moves within a file)
- `-C -C` (double): additionally searches all files in the **parent of the file-creation commit** — this is key: since commit 1 creates the destination as a full copy, blame traces every line back through the source
- `-C -C -C` (triple): searches all files in any commit (slower, not needed for this technique)
- Blame operates on individual lines with a **40 alphanumeric character threshold** — lines shorter than that (brief comments, headings) may not be traced. Lower with `-C -C20` if needed
- `git log --follow` will NOT trace through copies — only through whole-file renames. Use `git blame -C -C` for copy tracing
- GitHub/GitLab web UI does not use `-C` — blame there will show the extraction commit, not original authors. This technique is for CLI / IDE use
