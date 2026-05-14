# sv_yaml Design Spec

## Overview

sv_yaml is the YAML companion to sv_json in the sv_serde library. Same common API, backed by rapidyaml v0.12.1 via DPI-C. Adds YAML-specific features: multi-document, comments, anchors/aliases, tags, flow style output.

## Architecture

Same two-layer pattern as sv_json:
- C++ layer: rapidyaml engine, handle table, DPI functions (prefix `dpi_yaml_*`)
- SV layer: `sv_yaml` class in `sv_yaml_pkg.sv` (for VCS/Xcelium), raw DPI tests for Verilator

## Common API (identical to sv_json)

All methods from sv_json are replicated with the same signatures:
- Factory: parse, new_object, new_array, from_string/int/real/bool, make_null, set_strict_mode
- Type check: is_null/boolean/int/real/number/string/array/object, get_type
- Extract: as_string/int/real/bool, value_string/int/real/bool (with defaults)
- Access: get, at, at_path, contains, empty, size, key_at, get_keys
- Modify: set, push, insert_at, remove, remove_at, update (all immutable)
- Serialize: dump, dump_file

## YAML-Specific API

### Multi-Document
- `yaml_parse_all(string input)` → returns handle to sequence of documents
- First document accessible via `parse()` (backward compatible)

### Comments
- `yaml_comments(int h)` → string: get comment text on node
- `yaml_set_comment(int h, const char* text)` → int: set comment (returns new handle)

### Anchors & Aliases
- `yaml_anchor(int h)` → string: get anchor name (&name)
- `yaml_set_anchor(int h, const char* name)` → int: set anchor (returns new handle)
- `yaml_alias(int h)` → string: get alias name (*name) if alias node

### Tags
- `yaml_tag(int h)` → string: get tag (!!str, !!int, etc.)
- `yaml_set_tag(int h, const char* tag)` → int: set tag (returns new handle)

### Dump Variants
- `yaml_dump_flow(int h)` → string: flow style {key: value}
- `yaml_dump_with_comments(int h)` → string: preserve comments

## File Structure

```
sv_yaml/
├── src/
│   ├── sv_yaml_pkg.sv          # Package + types + class (VCS/Xcelium)
│   └── dpi/
│       ├── sv_yaml_dpi.h       # C++ header
│       ├── sv_yaml_dpi.cc      # C++ implementation (rapidyaml)
│       └── rapidyaml-0.12.1.hpp # Single-header (embedded)
└── tests/
    ├── sv_yaml_test.sv         # Test suite (DPI-level for Verilator)
    ├── main_yaml.cpp           # Verilator main
    └── data/
        ├── simple.yaml
        ├── anchors.yaml
        ├── comments.yaml
        ├── multiline.yaml
        ├── multi_doc.yaml
        └── complex.yaml
```

## Implementation Order

1. Directory structure + download rapidyaml
2. C++ DPI header (sv_yaml_dpi.h)
3. C++ DPI engine (sv_yaml_dpi.cc) — full implementation
4. SV package + class (sv_yaml_pkg.sv)
5. Test data files
6. Basic tests (Verilator)
7. YAML-specific tests (multi-doc, comments, anchors, tags, flow)
8. Complex YAML tests
