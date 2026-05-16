# sv_serde

SystemVerilog JSON/YAML Processing Library.

## Build

```bash
make -f run/Makefile.verilator run_test_json   # JSON SV API tests (51 tests)
make -f run/Makefile.verilator run_test_yaml   # YAML SV API tests (62 tests)
make -f run/Makefile.verilator run_test_all    # All SV API tests (113 tests)
```

## Structure

### sv_serde (unified)
- `sv_serde/src/sv_serde_pkg.sv` — Unified package exporting both sv_json_pkg and sv_yaml_pkg symbols

### sv_json
- `sv_json/src/sv_json_pkg.sv` — SV package with types, DPI imports, sv_json class
- `sv_json/src/dpi/sv_json_dpi.cc` — C++ DPI engine (nlohmann/json v3.12.0)
- `sv_json/src/dpi/sv_json_dpi.h` — C++ header
- `tests/test_json_class.sv` — JSON SV API test suite (51 tests)

### sv_yaml
- `sv_yaml/src/sv_yaml_pkg.sv` — SV package with types, DPI imports, sv_yaml class
- `sv_yaml/src/dpi/sv_yaml_dpi.cc` — C++ DPI engine (rapidyaml v0.12.1)
- `sv_yaml/src/dpi/sv_yaml_dpi.h` — C++ header
- `tests/test_yaml_class.sv` — YAML SV API test suite (62 tests)

## Usage

```systemverilog
// Unified import (both JSON and YAML)
import sv_serde_pkg::*;

// Or import individually
import sv_json_pkg::*;
import sv_yaml_pkg::*;

// JSON
sv_json j = sv_json::parse("{\"key\":\"value\"}");
string v = j.get("key").as_string();

// YAML
sv_yaml y = sv_yaml::parse("key: value");
string v2 = y.get("key").as_string();
```

## Notes

- Verilator 5.020 is used to run the public SystemVerilog API tests directly.
- The sv_json/sv_yaml classes work with full SV simulators (VCS, Xcelium).
- Common API: parse, get, at, at_path, set, push, remove, dump, and more.
- YAML-specific: yaml_parse_all, yaml_tag, yaml_anchor, yaml_dump_flow, yaml_comments.
