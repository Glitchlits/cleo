# Golden File Tests

Golden file tests compare command output against known-good "golden" files to detect output regressions.

## Directory Structure

```
tests/golden/
├── README.md           # This file
├── golden.bats         # BATS test runner for golden tests
├── fixtures/           # Test data fixtures
│   └── todo.json       # Stable test data
└── expected/           # Golden output files
    ├── list-text.golden
    ├── list-json.golden
    ├── stats-text.golden
    ├── dash-compact.golden
    └── ...
```

## Usage

### Running Golden Tests

```bash
# Run all golden tests
bats tests/golden/golden.bats

# Run specific test
bats tests/golden/golden.bats --filter "list"
```

### Updating Golden Files

When output intentionally changes, regenerate golden files:

```bash
UPDATE_GOLDEN=1 bats tests/golden/golden.bats
```

This will:
1. Run each command with the test fixture
2. Normalize timestamps and paths
3. Write output to `expected/*.golden` files
4. Report what was updated

### Normalization

Golden files are normalized to remove environment-specific values:
- Timestamps replaced with `TIMESTAMP`
- File paths replaced with relative paths
- Checksums replaced with `CHECKSUM`
- Execution times replaced with `XXms`

## Adding New Golden Tests

1. Add the test case to `golden.bats`
2. Run with `UPDATE_GOLDEN=1` to generate the golden file
3. Review the generated golden file
4. Commit both the test and golden file

## Test Cases

| Command | Golden File | Description |
|---------|-------------|-------------|
| `list --format text` | list-text.golden | Default task list output |
| `list --format json` | list-json.golden | JSON task list with _meta |
| `list --format jsonl` | list-jsonl.golden | JSONL streaming output |
| `stats` | stats-text.golden | Statistics display |
| `dash --compact` | dash-compact.golden | Compact dashboard |
| `labels` | labels-text.golden | Label listing |
| `phases` | phases-text.golden | Phase listing |
