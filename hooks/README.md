# Git hooks

## prepare-commit-msg

Removes `Co-authored-by: Cursor <cursoragent@cursor.com>` from commit messages so it never gets pushed.

**Install (run from repo root):**

```bash
cp hooks/prepare-commit-msg .git/hooks/prepare-commit-msg && chmod +x .git/hooks/prepare-commit-msg
```

After a fresh clone, run the above again to reinstall the hook.
