# sv_serde: SystemVerilog JSON/YAML Processing Library

## Overview

sv_serde is a SystemVerilog library for JSON and YAML serialization/deserialization.
It provides two independent classes (`sv_json` and `sv_yaml`) with consistent APIs,
each backed by a dedicated C++ engine via DPI-C.

**Current scope**: `sv_json` only (Phase 1-2). `sv_yaml` will follow after validation.

## Design Principles

1. **Complete feature support** — JSON and YAML features must all be supported
2. **Consistent API** — Same operations use the same method names across both classes
3. **Independent implementation** — Format-specific operations live in their own class with `yaml_` prefix
4. **Bottom-up implementation** — C++ engine first, then SV layer, then tests

## Directory Structure

```
sv_serde/
├── CLAUDE.md                        # Project context
├── CONTEXT.md                       # Domain glossary + API reference
├── Makefile.verilator               # Verilator build (local dev, phase 1)
├── Makefile.vcs                     # VCS build (future)
├── Makefile.xcelium                 # Xcelium build (future)
├── sv_json/                         # JSON subproject (Phase 1)
│   ├── src/
│   │   ├── sv_json_pkg.sv           # Package + DPI imports
│   │   ├── sv_json_types.sv         # Type enum
│   │   ├── sv_json.sv               # sv_json class
│   │   └── dpi/
│   │       ├── sv_json_dpi.h
│   │       ├── sv_json_dpi.cc       # nlohmann/json engine
│   │       └── nlohmann/json.hpp    # v3.12.0 (embedded)
│   └── tests/
│       ├── sv_json_test.sv          # 147 tests
│       ├── data/deep.json
│       └── data/complex.json
├── sv_yaml/                         # YAML subproject (Phase 3, future)
│   ├── src/
│   │   ├── sv_yaml_pkg.sv
│   │   ├── sv_yaml_types.sv
│   │   ├── sv_yaml.sv
│   │   └── dpi/
│   │       ├── sv_yaml_dpi.h
│   │       ├── sv_yaml_dpi.cc       # rapidyaml engine
│   │       └── rapidyaml/
│   └── tests/
│       ├── sv_yaml_test.sv
│       └── data/
└── docs/
    └── superpowers/specs/
```

## C++ Layer

### Handle Table

Each engine maintains an independent handle table mapping integer IDs to C++ objects:

```cpp
// sv_json_dpi.cc
static std::unordered_map<int, nlohmann::json> g_json_handles;
static int g_json_next_handle = 1;
static std::unordered_map<int, std::string> g_json_strings;
static int g_json_next_string = 1;
```

### Key Functions

```cpp
// Object lifecycle
int dpi_json_new_object();
int dpi_json_new_array();
int dpi_json_parse(const char* input);
void dpi_json_destroy(int handle);

// Type checking
int dpi_json_is_null(int h);
int dpi_json_is_boolean(int h);
int dpi_json_is_int(int h);
int dpi_json_is_real(int h);
int dpi_json_is_string(int h);
int dpi_json_is_array(int h);
int dpi_json_is_object(int h);
int dpi_json_get_type(int h);

// Value extraction
int dpi_json_as_string(int h);  // returns string handle
int dpi_json_as_int(int h);
double dpi_json_as_real(int h);
int dpi_json_as_bool(int h);

// Structure access
int dpi_json_get(int h, const char* key);
int dpi_json_at(int h, int idx);
int dpi_json_at_path(int h, const char* path);
int dpi_json_contains(int h, const char* key);
int dpi_json_empty(int h);
int dpi_json_size(int h);

// Modification (returns new handle)
int dpi_json_set(int h, const char* key, int val_h);
int dpi_json_push(int h, int val_h);
int dpi_json_insert_at(int h, int idx, int val_h);
int dpi_json_remove(int h, const char* key);
int dpi_json_remove_at(int h, int idx);
int dpi_json_update(int h, int other_h);

// Serialization
int dpi_json_dump(int h, int indent);
int dpi_json_dump_file(int h, const char* fname, int indent);
```

## SV Layer

### Type Enum

```systemverilog
typedef enum int {
    SV_JSON_NULL    = 0,
    SV_JSON_BOOLEAN = 1,
    SV_JSON_INT     = 2,
    SV_JSON_REAL    = 3,
    SV_JSON_STRING  = 4,
    SV_JSON_ARRAY   = 5,
    SV_JSON_OBJECT  = 6
} sv_json_type_e;
```

### sv_json Class

Immutable value semantics. All modification methods return a NEW object.

#### Static Factory Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `::parse(string input)` | object or null | Parse from string or file path (auto-detect) |
| `::new_object()` | object | Empty map `{}` |
| `::new_array()` | object | Empty sequence `[]` |
| `::from_string(string val)` | object | String value |
| `::from_int(int val)` | object | Integer value |
| `::from_real(real val)` | object | Float value |
| `::from_bool(bit val)` | object | Boolean value |
| `::make_null()` | object | Null value |
| `::set_strict_mode(bit enable)` | void | Toggle strict error mode |

#### Type Checking

| Method | Returns | Description |
|--------|---------|-------------|
| `.is_null()` | bit | True if null |
| `.is_boolean()` | bit | True if boolean |
| `.is_int()` | bit | True if integer |
| `.is_real()` | bit | True if float |
| `.is_number()` | bit | True if int or real |
| `.is_string()` | bit | True if string |
| `.is_array()` | bit | True if sequence/array |
| `.is_object()` | bit | True if map/object |
| `.get_type()` | sv_json_type_e | Type enum |

#### Value Extraction

| Method | Returns | Description |
|--------|---------|-------------|
| `.as_string()` | string | String value |
| `.as_int()` | int | Integer value |
| `.as_real()` | real | Float value |
| `.as_bool()` | bit | Boolean value |
| `.value_string(key, default)` | string | String with fallback |
| `.value_int(key, default)` | int | Int with fallback |
| `.value_real(key, default)` | real | Real with fallback |
| `.value_bool(key, default)` | bit | Bool with fallback |

#### Structure Access

| Method | Returns | Description |
|--------|---------|-------------|
| `.get(string key)` | object or null | Map member by key |
| `.at(int idx)` | object or null | Sequence element by index |
| `.at_path(string path)` | object or null | JSON Pointer path access (RFC 6901) |
| `.contains(string key)` | bit | Key existence check |
| `.empty()` | bit | True if no elements |
| `.size()` | int | Element count |
| `.key_at(int index)` | string | Key at index |
| `.get_keys(output string keys[$])` | void | All keys into queue |

#### Modification (Immutable)

All return a NEW object. Original unchanged.

| Method | Returns | Description |
|--------|---------|-------------|
| `.set(string key, value)` | object | New map with key set |
| `.push(value)` | object | New sequence with element appended |
| `.insert_at(int idx, value)` | object | New sequence with element inserted |
| `.remove(string key)` | object | New map with key removed |
| `.remove_at(int idx)` | object | New sequence with element removed |
| `.update(other)` | object | New map merged with other's keys |

#### Serialization

| Method | Returns | Description |
|--------|---------|-------------|
| `.dump(string fname="", int indent=2)` | string | No args → pretty string; with fname → write to file |
| `.dump("", -1)` | string | Compact string |

### Path Access (JSON Pointer RFC 6901)

```
/foo/bar          Object member bar inside foo
/foo/0            Array element at index 0 inside foo
/foo/bar~1baz     Key containing / (escaped as ~1)
/foo/bar~0tilde   Key containing ~ (escaped as ~0)
```

### Error Handling

| Mode | Behavior |
|------|----------|
| Non-strict (default) | Missing keys → null, type mismatch → default value |
| Strict | `$fatal` on any error |

## Type Mapping

| Value Type | sv_json_type_e | SV check | C++ (JSON) |
|------------|---------------|----------|------------|
| null | SV_JSON_NULL (0) | `is_null()` | `val.is_null()` |
| boolean | SV_JSON_BOOLEAN (1) | `is_boolean()` | `val.is_bool()` |
| integer | SV_JSON_INT (2) | `is_int()` | `val.is_number_integer()` |
| float | SV_JSON_REAL (3) | `is_real()` | `val.is_number_float()` |
| string | SV_JSON_STRING (4) | `is_string()` | `val.is_string()` |
| sequence | SV_JSON_ARRAY (5) | `is_array()` | `val.is_array()` |
| map | SV_JSON_OBJECT (6) | `is_object()` | `val.is_object()` |

## Thread Safety

- Parsed data is immutable — safe for concurrent reads
- Construction is mutable — build in one thread, then share
- Modification returns new objects — no in-place mutation
- No locking needed

## Build System

### Verilator (local development)

```bash
make -f Makefile.verilator run_test_json
make -f Makefile.verilator run_test_all
```

### VCS / Xcelium (future)

```bash
make -f Makefile.vcs run_test_all
make -f Makefile.xcelium run_test_all
```

## Implementation Plan

### Phase 1: sv_json (current scope)

1. **Directory structure + Makefile.verilator**
   - Create `sv_serde/sv_json/` tree
   - Verilator Makefile that compiles SV + C++ together

2. **C++ DPI engine** (`sv_json_dpi.cc`)
   - Embed `nlohmann/json.hpp` v3.12.0
   - Handle table implementation
   - All DPI functions from API spec
   - JSON Pointer path support

3. **SV package + types**
   - `sv_json_pkg.sv`: DPI import declarations
   - `sv_json_types.sv`: `sv_json_type_e` enum

4. **sv_json class** (`sv_json.sv`)
   - Full API implementation
   - All methods delegate to DPI calls

5. **Tests**
   - `sv_json_test.sv`: 147 test cases
   - `data/complex.json`: Complex nested structure
   - `data/deep.json`: Deep nesting stress test

### Phase 2: sv_yaml (future)

- Embed rapidyaml headers
- Implement `sv_yaml_dpi.cc`
- Implement `sv_yaml` class
- YAML-specific features (comments, anchors, tags, multi-doc)

### Phase 3: Documentation (future)

- Update CLAUDE.md and CONTEXT.md
- Document both APIs

## Testing Strategy

### sv_json Test Categories

1. **Basic types**: null, bool, int, real, string
2. **Structures**: object, array, nested
3. **Factory methods**: new_object, new_array, from_*
4. **Access**: get, at, at_path, contains, size, empty
5. **Modification**: set, push, insert_at, remove, remove_at, update
6. **Serialization**: dump (pretty, compact, file)
7. **Error handling**: strict mode, missing keys, type mismatches
8. **Edge cases**: empty structures, unicode, large numbers

### complex.json Test Scenarios

1. Read file, verify root is object, size > 0
2. Navigate all levels, check all types
3. Access nested objects: `project.config.endpoints[0].host`
4. Access nested arrays: `matrix[1][2]` → 6
5. Mixed array type verification
6. Edge cases: empty string/array/object, zero, negative int, large int
7. Modify deep node (immutable), write to file
8. Re-read and verify round-trip integrity
9. Iteration: `get_keys()` on all objects, `size()` on all arrays
10. `contains()` on keys with null values
11. Path access: `at_path("/project/config/endpoints/0/host")`
12. Path access deep: `at_path("/test_data/deep_nested/l1/l2/l3/l4/l5/value")`
13. Path access array: `at_path("/matrix/1/2")` → 6
14. Path missing: `at_path("/nonexistent/path")` → null

## Iteration Pattern

SV-2012 has no iterator pattern. Use index-based iteration:

```systemverilog
// Object iteration
string keys[$];
data.get_keys(keys);
foreach (keys[i]) begin
    sv_json v = data.get(keys[i]);
end

// Array iteration
for (int i = 0; i < data.size(); i++) begin
    sv_json v = data.at(i);
end
```
