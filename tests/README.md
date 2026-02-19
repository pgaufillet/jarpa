# JARPA Plugin Test Suite

Automated tests for validating the JARPA plugin structure, configurations, and installation in Claude Code.

## Quick Start

```bash
# Run structure and unit tests (fast, no Claude CLI needed)
./tests/run_all_tests.sh

# Run ALL tests including Claude Code installation tests
./tests/run_all_tests.sh --full

# Run with verbose output
./tests/run_all_tests.sh -v --full
```

## Test Suites

### 1. Plugin Structure Tests (`test_plugin.sh`)

Validates plugin files and configurations without requiring Claude Code.

**What it tests:**
- **Manifest**: `plugin.json` validity and required fields
- **Hooks**: `hooks.json` schema, hook types, script paths
- **MCP**: `.mcp.json` configuration, server definition
- **Agents**: YAML frontmatter, required fields (name, description, model, color)
- **Commands**: YAML frontmatter, name format (`jarpa:<name>`)
- **Skills**: SKILL.md structure and metadata
- **Templates**: File existence and content
- **Scripts**: Executability, syntax, shebangs
- **Integration**: Cross-references between components

**Run individually:**
```bash
./tests/test_plugin.sh              # All tests
./tests/test_plugin.sh manifest     # Just manifest tests
./tests/test_plugin.sh hooks        # Just hooks tests
./tests/test_plugin.sh mcp          # Just MCP tests
./tests/test_plugin.sh agents       # Just agent tests
./tests/test_plugin.sh commands     # Just command tests
./tests/test_plugin.sh skills       # Just skill tests
./tests/test_plugin.sh templates    # Just template tests
./tests/test_plugin.sh scripts      # Just script tests
./tests/test_plugin.sh integration  # Just integration tests
```

### 2. MCP Server Tests (`test_mcp_server.py`)

Python unit tests for the context-monitor MCP server.

**What it tests:**
- Server module can be parsed/imported
- Context file format expectations
- Threshold logic (OK/WARNING/CRITICAL)
- `should_close_session` behavior with custom thresholds
- Error handling (missing file, malformed JSON)
- Output format compliance
- Configuration (file paths, transport mode)

**Run individually:**
```bash
python3 tests/test_mcp_server.py      # All tests
python3 tests/test_mcp_server.py -v   # Verbose output
```

## Requirements

- **bash** (for shell tests)
- **jq** (for JSON validation) - `apt install jq`
- **python3** (for Python tests)

## CI/CD Integration

Add to your CI pipeline:

```yaml
# GitHub Actions example
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Install dependencies
      run: sudo apt-get install -y jq
    - name: Run tests
      run: ./tests/run_all_tests.sh
```

## Test Output

Tests use colored output:
- 🟢 `[PASS]` - Test passed
- 🔴 `[FAIL]` - Test failed
- 🔵 `[INFO]` - Informational message
- 🟡 `[WARN]` - Warning (non-fatal)

Exit codes:
- `0` - All tests passed
- `1` - One or more tests failed

## Adding New Tests

### Adding plugin structure tests

Edit `test_plugin.sh` and add assertions using the helper functions:

```bash
# Check file exists
assert_file_exists "$PLUGIN_ROOT/path/to/file" "Description"

# Check directory exists
assert_dir_exists "$PLUGIN_ROOT/path/to/dir" "Description"

# Check valid JSON
assert_json_valid "$file" "Description"

# Check JSON has field
assert_json_has_field "$file" ".field.path" "Description"

# Check YAML frontmatter exists
assert_yaml_frontmatter "$file" "Description"

# Check YAML has field
assert_yaml_has_field "$file" "fieldname" "Description"

# Check file is executable
assert_executable "$file" "Description"

# Check Python syntax
assert_python_syntax "$file" "Description"

# Check shell syntax
assert_shell_syntax "$file" "Description"

# Check file contains pattern
assert_contains "$file" "pattern" "Description"
```

### Adding MCP server tests

Add test methods to the appropriate class in `test_mcp_server.py`:

```python
class TestContextMonitorServer(unittest.TestCase):
    def test_new_feature(self):
        """Test description."""
        # Test implementation
        self.assertTrue(condition)
```

### 3. Installation Tests (`test_plugin_installation.sh`)

**Requires:** Claude Code CLI installed

Tests actual plugin installation by invoking Claude Code with `--plugin-dir`:

**What it tests:**
- Plugin loads without errors
- Commands are registered (`/jarpa:init`, `/jarpa:status`, etc.)
- MCP server is recognized
- Plugin metadata is correct
- Hooks configuration is valid
- Templates are present

**Run individually:**
```bash
./tests/test_plugin_installation.sh
```

This test creates a temporary directory and invokes Claude Code with prompts to verify plugin functionality.

## Future Enhancements

- [ ] Hook execution simulation tests (trigger SessionStart, etc.)
- [ ] End-to-end workflow tests (`/jarpa:init` → work → `/jarpa:session-end`)
- [ ] Performance benchmarks for MCP server
- [ ] CI/CD integration with Claude Code in Docker
