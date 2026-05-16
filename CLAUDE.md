# sv_serde

SystemVerilog JSON/YAML Processing Library.

## Build

```bash
make -f run/Makefile.verilator run_test_json     # JSON SV API tests (64 tests)
make -f run/Makefile.verilator run_test_yaml     # YAML SV API tests (75 tests)
make -f run/Makefile.verilator run_test_unified  # Unified import tests (25 tests)
make -f run/Makefile.verilator run_test_all      # All tests (164 tests)
```

## Structure

### sv_serde (unified)
- `sv_serde/src/sv_serde_pkg.sv` — Unified package with type enums (SERDE_*) and backward-compatible constants (SV_JSON_*, SV_YAML_*)

### sv_json
- `sv_json/src/sv_json_pkg.sv` — SV package with types, DPI imports, sv_json class
- `sv_json/src/dpi/sv_json_dpi.cc` — C++ DPI engine (nlohmann/json v3.12.0)
- `sv_json/src/dpi/sv_json_dpi.h` — C++ header
- `tests/test_json_class.sv` — JSON SV API test suite (64 tests)

### sv_yaml
- `sv_yaml/src/sv_yaml_pkg.sv` — SV package with types, DPI imports, sv_yaml class
- `sv_yaml/src/dpi/sv_yaml_dpi.cc` — C++ DPI engine (rapidyaml v0.12.1)
- `sv_yaml/src/dpi/sv_yaml_dpi.h` — C++ header
- `tests/test_yaml_class.sv` — YAML SV API test suite (75 tests)

## Usage

```systemverilog
// Import types and constants from sv_serde_pkg
import sv_serde_pkg::*;

// Import classes individually (required — classes cannot be re-exported)
import sv_json_pkg::sv_json;
import sv_yaml_pkg::sv_yaml;

// JSON
sv_json j = sv_json::parse("{\"key\":\"value\"}");
string v = j.get("key").as_string();

// YAML
sv_yaml y = sv_yaml::parse("key: value");
string v2 = y.get("key").as_string();

// Type checking uses SERDE_* constants from sv_serde_pkg
if (j.get("key").get_type() == SERDE_STRING) begin
  // ...
end
```

## Notes

- Tested on Verilator 5.048 and Synopsys VCS W-2024.09.
- The sv_json/sv_yaml classes work with both open-source and commercial SV simulators.
- Common API: parse, get, at, at_path, set, push, remove, dump, clone, and more.
- YAML-specific: yaml_parse_all, yaml_tag, yaml_anchor, yaml_dump_flow, yaml_comments.
