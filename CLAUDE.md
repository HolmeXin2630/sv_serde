# sv_serde

SystemVerilog JSON/YAML Processing Library.

## Build

```bash
make -f Makefile.verilator run_test_json
```

## Structure

- `sv_json/src/sv_json_pkg.sv` — SV package with types, DPI imports, sv_json class
- `sv_json/src/dpi/sv_json_dpi.cc` — C++ DPI engine (nlohmann/json)
- `sv_json/src/dpi/sv_json_dpi.h` — C++ header
- `sv_json/tests/sv_json_test.sv` — Test suite (97 tests)

## Usage

```systemverilog
import sv_json_pkg::*;

sv_json j = sv_json::parse("{\"key\":\"value\"}");
string v = j.get("key").as_string();  // "value"
```

## Notes

- Verilator 5.020 does not support SystemVerilog classes. Tests call DPI functions directly.
- The sv_json class works with full SV simulators (VCS, Xcelium).
- C++ DPI engine uses nlohmann/json v3.12.0 (single-header, embedded).
