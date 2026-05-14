# sv_serde

SystemVerilog JSON/YAML Processing Library.

## Build

```bash
make -f Makefile.verilator run_test_json   # JSON only (97 tests)
make -f Makefile.verilator run_test_yaml   # YAML only (124 tests)
make -f Makefile.verilator run_test_all    # Both (221 tests)
```

## Structure

### sv_json
- `sv_json/src/sv_json_pkg.sv` — SV package with types, DPI imports, sv_json class
- `sv_json/src/dpi/sv_json_dpi.cc` — C++ DPI engine (nlohmann/json v3.12.0)
- `sv_json/src/dpi/sv_json_dpi.h` — C++ header
- `sv_json/tests/sv_json_test.sv` — Test suite (97 tests)

### sv_yaml
- `sv_yaml/src/sv_yaml_pkg.sv` — SV package with types, DPI imports, sv_yaml class
- `sv_yaml/src/dpi/sv_yaml_dpi.cc` — C++ DPI engine (rapidyaml v0.12.1)
- `sv_yaml/src/dpi/sv_yaml_dpi.h` — C++ header
- `sv_yaml/tests/sv_yaml_test.sv` — Test suite (124 tests)

## Usage

```systemverilog
// JSON
import sv_json_pkg::*;
sv_json j = sv_json::parse("{\"key\":\"value\"}");
string v = j.get("key").as_string();

// YAML
import sv_yaml_pkg::*;
sv_yaml y = sv_yaml::parse("key: value");
string v2 = y.get("key").as_string();
```

## Notes

- Verilator 5.020 does not support SystemVerilog classes. Tests call DPI functions directly.
- The sv_json/sv_yaml classes work with full SV simulators (VCS, Xcelium).
- Common API: parse, get, at, at_path, set, push, remove, dump, and more.
- YAML-specific: yaml_parse_all, yaml_tag, yaml_anchor, yaml_dump_flow, yaml_comments.
