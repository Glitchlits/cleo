# Development Scripts

Scripts for project development and maintenance. **Not shipped to users.**

## Scripts

| Script | Purpose |
|--------|---------|
| `bump-version.sh` | Bump semantic version across all files |
| `validate-version.sh` | Verify version consistency |
| `benchmark-performance.sh` | Performance testing |

## Usage

```bash
# From project root
./dev/bump-version.sh patch    # 0.16.0 → 0.16.1
./dev/bump-version.sh minor    # 0.16.0 → 0.17.0
./dev/bump-version.sh major    # 0.16.0 → 1.0.0

./dev/validate-version.sh      # Check version sync

./dev/benchmark-performance.sh # Run benchmarks
```

## Note

These scripts are excluded from `install.sh` and never copied to `~/.claude-todo/`.
