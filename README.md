# sv_serde

SystemVerilog JSON/YAML Processing Library. Parse, query, modify, and serialize JSON and YAML data directly in SystemVerilog via DPI-C.

[中文说明](README_zh.md)

## Features

- **JSON** — Full JSON support via [nlohmann/json](https://github.com/nlohmann/json) v3.12.0
- **YAML** — Full YAML 1.2 support via [rapidyaml](https://github.com/biojppm/rapidyaml) v0.12.1, including anchors, aliases, tags, multi-document, and comments
- **Consistent API** — `sv_json` and `sv_yaml` share identical method names for common operations
- **Immutable semantics** — All modifications return new objects, original data unchanged
- **JSON Pointer** — RFC 6901 path access (`/foo/bar/0/baz`) for both JSON and YAML
- **Zero dependencies** — Header-only C++ libraries embedded in the repo, no external tools needed

## Quick Start

```systemverilog
import sv_json_pkg::*;

// Parse JSON
sv_json j = sv_json::parse("{\"name\":\"Alice\",\"scores\":[95,87,92]}");

// Query
string name = j.get("name").as_string();           // "Alice"
int first    = j.get("scores").at(0).as_int();     // 95

// Path access
int score = j.at_path("/scores/1").as_int();        // 87

// Modify (returns new object)
sv_json updated = j.set("name", sv_json::from_string("Bob"));
updated.dump("output.json");
```

```systemverilog
import sv_yaml_pkg::*;

// Parse YAML
sv_yaml y = sv_yaml::parse("name: Alice\nscores:\n  - 95\n  - 87");

// Same API as sv_json
string name = y.get("name").as_string();
int first   = y.get("scores").at(0).as_int();

// YAML-specific: multi-document
sv_yaml docs = sv_yaml::yaml_parse_all("a: 1\n---\nb: 2");

// YAML-specific: tags
string tag = y.get("name").yaml_tag();

// YAML-specific: flow style output
string flow = y.yaml_dump_flow();
```

## Integration

### Prerequisites

- SystemVerilog-2012 simulator with DPI-C support (VCS, Xcelium, Verilator)
- C++17 compiler (g++ or clang++)
- Verilator (for local development/testing)

### File Layout

Copy the following into your project:

```
your_project/
├── sv_serde/
│   └── src/
│       └── sv_serde_pkg.sv            # Unified package (imports both)
├── sv_json/
│   ├── src/
│   │   ├── sv_json_pkg.sv        # Package + class
│   │   └── dpi/
│   │       ├── sv_json_dpi.h     # C++ header
│   │       ├── sv_json_dpi.cc    # C++ implementation
│   │       └── nlohmann/json.hpp # JSON engine (embedded)
│   └── (tests/ — optional)
├── sv_yaml/                       # Optional: YAML support
│   ├── src/
│   │   ├── sv_yaml_pkg.sv
│   │   └── dpi/
│   │       ├── sv_yaml_dpi.h
│   │       ├── sv_yaml_dpi.cc
│   │       └── rapidyaml-0.12.1.hpp
│   └── (tests/ — optional)
```

### Import Options

Three ways to import, depending on your needs:

```systemverilog
import sv_json_pkg::*;   // JSON only
import sv_yaml_pkg::*;   // YAML only
import sv_serde_pkg::*;       // Both JSON and YAML
```

### VCS

```bash
# JSON only
vcs -full64 -sverilog \
    sv_json/src/sv_json_pkg.sv your_test.sv \
    sv_json/src/dpi/sv_json_dpi.cc \
    -o simv

# JSON + YAML
vcs -full64 -sverilog \
    sv_json/src/sv_json_pkg.sv \
    sv_yaml/src/sv_yaml_pkg.sv \
    your_test.sv \
    sv_json/src/dpi/sv_json_dpi.cc \
    sv_yaml/src/dpi/sv_yaml_dpi.cc \
    -o simv
```

### Xcelium

```bash
xrun -sv \
     sv_json/src/sv_json_pkg.sv your_test.sv \
     sv_json/src/dpi/sv_json_dpi.cc
```

### Verilator (testing only)

```bash
make -f run/Makefile.verilator run_test_json   # JSON SV API tests (51 tests)
make -f run/Makefile.verilator run_test_yaml   # YAML SV API tests (62 tests)
make -f run/Makefile.verilator run_test_all    # All SV API tests (113 tests)
```

> **Note:** The Verilator test flow now exercises the public SystemVerilog API directly by importing packages and calling `sv_json`/`sv_yaml` methods.

## API Reference

### Common API (sv_json and sv_yaml)

#### Parse & Create

| Method | Returns | Description |
|--------|---------|-------------|
| `::parse(string)` | object | Parse JSON/YAML string or file path |
| `::new_object()` | object | Empty map `{}` |
| `::new_array()` | object | Empty sequence `[]` |
| `::from_string(string)` | object | String value |
| `::from_int(int)` | object | Integer value |
| `::from_real(real)` | object | Float value |
| `::from_bool(bit)` | object | Boolean value |
| `::make_null()` | object | Null value |
| `::set_strict_mode(bit)` | void | Enable/disable strict error mode |

#### Type Check

| Method | Returns | Description |
|--------|---------|-------------|
| `.is_null()` | `bit` | True if null |
| `.is_boolean()` | `bit` | True if boolean |
| `.is_int()` | `bit` | True if integer |
| `.is_real()` | `bit` | True if float |
| `.is_number()` | `bit` | True if integer or float |
| `.is_string()` | `bit` | True if string |
| `.is_array()` | `bit` | True if array |
| `.is_object()` | `bit` | True if object |

#### Value Extraction

| Method | Returns | Description |
|--------|---------|-------------|
| `.as_string()` | `string` | String value |
| `.as_int()` | `int` | Integer value |
| `.as_real()` | `real` | Float value |
| `.as_bool()` | `bit` | Boolean value |
| `.value_string(key, default)` | `string` | String with fallback |
| `.value_int(key, default)` | `int` | Int with fallback |
| `.value_real(key, default)` | `real` | Real with fallback |
| `.value_bool(key, default)` | `bit` | Bool with fallback |

#### Structure Access

| Method | Returns | Description |
|--------|---------|-------------|
| `.get(string key)` | object | Map member by key |
| `.at(int idx)` | object | Array element by index |
| `.at_path(string path)` | object | JSON Pointer path (RFC 6901) |
| `.contains(string key)` | `bit` | Key existence check |
| `.empty()` | `bit` | True if no elements |
| `.size()` | `int` | Element count |
| `.key_at(int idx)` | `string` | Key name at index |
| `.get_keys(output keys[$])` | `void` | All keys into queue |

#### Modification (Immutable)

All return a **new** object. Original unchanged.

| Method | Returns | Description |
|--------|---------|-------------|
| `.set(key, value)` | object | New map with key set |
| `.push(value)` | object | New array with element appended |
| `.insert_at(idx, value)` | object | New array with element inserted |
| `.remove(key)` | object | New map with key removed |
| `.remove_at(idx)` | object | New array with element removed |
| `.update(other)` | object | New map merged with other's keys |

#### Serialization

| Method | Returns | Description |
|--------|---------|-------------|
| `.dump()` | `string` | Pretty-printed string |
| `.dump("", -1)` | `string` | Compact string |
| `.dump("file.json")` | `string` | Write to file, returns `"ok"` or `"error"` |
| `.dump_file(fname, indent)` | `int` | Write to file (returns 0 on success) |

### YAML-Specific API

| Method | Returns | Description |
|--------|---------|-------------|
| `::yaml_parse_all(string)` | object | Parse all documents (root is sequence) |
| `.yaml_comments()` | `string` | Get comment text |
| `.yaml_set_comment(string)` | object | Set comment (returns new node) |
| `.yaml_anchor()` | `string` | Get anchor name (`&name`) |
| `.yaml_set_anchor(string)` | object | Set anchor (returns new node) |
| `.yaml_alias()` | `string` | Get alias name (`*name`) |
| `.yaml_tag()` | `string` | Get tag (`!!str`, `!!int`, etc.) |
| `.yaml_set_tag(string)` | object | Set tag (returns new node) |
| `.yaml_dump_flow()` | `string` | Flow style output (`{key: value}`) |
| `.yaml_dump_with_comments()` | `string` | Dump preserving comments |

## More Examples

### Build JSON from scratch

```systemverilog
sv_json obj = sv_json::new_object();
obj = obj.set("name", sv_json::from_string("test"));
obj = obj.set("count", sv_json::from_int(42));
obj = obj.set("active", sv_json::from_bool(1));

sv_json arr = sv_json::new_array();
arr = arr.push(sv_json::from_int(1));
arr = arr.push(sv_json::from_int(2));
arr = arr.push(sv_json::from_int(3));
obj = obj.set("items", arr);

// Result: {"name":"test","count":42,"active":true,"items":[1,2,3]}
string json_str = obj.dump();
```

### Iterate over object keys

```systemverilog
sv_json data = sv_json::parse("{\"a\":1,\"b\":2,\"c\":3}");
string keys[$];
data.get_keys(keys);
foreach (keys[i]) begin
    $display("%s = %0d", keys[i], data.get(keys[i]).as_int());
end
```

### Nested path access

```systemverilog
sv_json root = sv_json::parse "{\"config\":{\"db\":{\"host\":\"localhost\",\"port\":3306}}}";
string host = root.at_path("/config/db/host").as_string();  // "localhost"
int port    = root.at_path("/config/db/port").as_int();     // 3306
```

### YAML merge keys and anchors

```systemverilog
sv_yaml y = sv_yaml::parse({
    "defaults: &defaults\n",
    "  color: blue\n",
    "  size: large\n",
    "item:\n",
    "  <<: *defaults\n",
    "  name: widget"
});

string color = y.get("item").get("color").as_string();  // "blue" (merged)
string name  = y.get("item").get("name").as_string();   // "widget"
```

### Read config with defaults

```systemverilog
sv_json cfg = sv_json::parse("config.json");
int timeout = cfg.value_int("timeout_ms", 5000);   // 5000 if missing
string mode = cfg.value_string("mode", "release");  // "release" if missing
```

## Testing

```bash
# Run all tests
make -f run/Makefile.verilator run_test_all

# Run JSON tests only
make -f run/Makefile.verilator run_test_json

# Run YAML tests only
make -f run/Makefile.verilator run_test_yaml

# Clean build artifacts
make -f run/Makefile.verilator clean
```

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐
│   sv_json_pkg.sv    │    │   sv_yaml_pkg.sv    │
│   (SV class)        │    │   (SV class)        │
│   DPI imports       │    │   DPI imports       │
└─────────┬───────────┘    └─────────┬───────────┘
          │                          │
          ▼                          ▼
┌─────────────────────┐    ┌─────────────────────┐
│  sv_json_dpi.cc     │    │  sv_yaml_dpi.cc     │
│  nlohmann/json      │    │  rapidyaml          │
│  handle table       │    │  handle table       │
└─────────────────────┘    └─────────────────────┘
```

Each format has an independent C++ engine. Objects are managed via integer handles — the SV layer never sees raw C++ pointers.

## License

This project embeds [nlohmann/json](https://github.com/nlohmann/json) (MIT License) and [rapidyaml](https://github.com/biojppm/rapidyaml) (MIT License).
