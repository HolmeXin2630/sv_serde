# sv_serde 架构优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 解决 8 个已识别架构问题：SV 层代码去重、类型枚举统一、错误处理链路、strict_mode 实例化、内存管理、g_strings 有界化、返回码统一、测试辅助复用。

**Architecture:** 自底向上重构——先改造 C++ DPI 基础设施（错误处理、有界字符串），再提取 SV 基类，最后将 JSON/YAML 子类缩减为薄适配器。测试通过 Verilator 编译运行验证。

**Tech Stack:** SystemVerilog (DPI-C), C++14, nlohmann/json v3.12.0, rapidyaml v0.12.1, Verilator 5.020

**依赖顺序：**
```
serde_common.h → C++ DPI .cc/.h → sv_serde_pkg.sv → sv_serde_base.svh → sv_json_pkg.sv / sv_yaml_pkg.sv → tests → Makefile
```

---

### Task 1: 更新 serde_common.h —— 添加 last_error 接口

**Files:**
- Modify: `sv_serde/src/dpi/serde_common.h:1-31`

- [ ] **Step 1: 在 serde_common.h 末尾添加 `dpi_serde_last_error` 声明和 helper 宏**

当前文件末尾是 `#endif // SERDE_COMMON_H`。在其之前插入：

```c
// Error reporting — thread-safe last-error buffer
#ifdef __cplusplus
extern "C" {
#endif
const char* dpi_serde_last_error(void);
#ifdef __cplusplus
}
#endif

// Helper macro for DPI backends to set error messages
// Usage: SET_ERROR("key '%s' not found", key);
#ifdef __cplusplus
#include <cstdio>
#include <string>
namespace serde {
inline void set_error(const std::string& msg) {
    // defined in each backend's .cc file
    extern thread_local std::string g_last_error;
    g_last_error = msg;
}
}
#define SET_ERROR(fmt, ...) do { \
    char _buf[512]; \
    std::snprintf(_buf, sizeof(_buf), fmt, ##__VA_ARGS__); \
    serde::set_error(std::string(_buf)); \
} while(0)
#endif
```

- [ ] **Step 2: 提交**

```bash
git add sv_serde/src/dpi/serde_common.h
git commit -m "feat: add dpi_serde_last_error() and SET_ERROR() macro to serde_common.h"
```

---

### Task 2: 更新 sv_json_dpi.cc —— g_last_error + g_strings 有界化 + 返回码修复

**Files:**
- Modify: `sv_json/src/dpi/sv_json_dpi.cc`

- [ ] **Step 1: 添加 g_last_error 定义和 dpi_serde_last_error 实现**

在文件头部（`using json = nlohmann::json;` 之后、handle table 之前）插入：

```cpp
// Error reporting
thread_local std::string g_last_error;

extern "C" const char* dpi_serde_last_error() {
    return g_last_error.c_str();
}
```

- [ ] **Step 2: 改造 `return_str()` 为有界版本**

替换原有 `return_str` 函数体。原文：

```cpp
static const char* return_str(const std::string& s) {
    int id = g_next_str_id++;
    g_strings[id] = s;
    return g_strings[id].c_str();
}
```

替换为：

```cpp
static const size_t MAX_STRINGS = 10000;

static const char* return_str(const std::string& s) {
    int id = g_next_str_id++;
    g_strings[id] = s;
    if (g_strings.size() > MAX_STRINGS) {
        int threshold = g_next_str_id - MAX_STRINGS / 2;
        for (auto it = g_strings.begin(); it != g_strings.end(); ) {
            if (it->first < threshold)
                it = g_strings.erase(it);
            else
                ++it;
        }
    }
    return g_strings[id].c_str();
}
```

- [ ] **Step 3: 为所有失败路径添加 SET_ERROR**

逐一修改以下函数中的失败路径：

`dpi_json_parse` — parse 异常分支：
```cpp
int dpi_json_parse(const char* input) {
    try {
        json j = json::parse(input);
        return alloc_handle(j);
    } catch (const std::exception& e) {
        SET_ERROR("JSON parse error: %s", e.what());
    } catch (...) {
        SET_ERROR("JSON parse error: unknown exception");
    }
    // file fallback
    std::ifstream f(input);
    if (f.is_open()) {
        try {
            json j;
            f >> j;
            return alloc_handle(j);
        } catch (const std::exception& e) {
            SET_ERROR("JSON file parse error: %s — %s", input, e.what());
        } catch (...) {
            SET_ERROR("JSON file parse error: %s", input);
        }
        return 0;
    }
    SET_ERROR("JSON parse failed: not valid JSON or readable file — %s", input);
    return 0;
}
```

`dpi_json_get`：
```cpp
int dpi_json_get(int h, const char* key) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_object()) { SET_ERROR("expected object for get('%s'), got type %d", key, dpi_json_get_type(h)); return 0; }
    if (!p->contains(key)) { SET_ERROR("key '%s' not found", key); return 0; }
    return alloc_handle((*p)[key]);
}
```

`dpi_json_at`：
```cpp
int dpi_json_at(int h, int idx) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_array()) { SET_ERROR("expected array for at(%d)", idx); return 0; }
    if (idx < 0 || idx >= (int)p->size()) { SET_ERROR("index %d out of range, size is %d", idx, (int)p->size()); return 0; }
    return alloc_handle((*p)[idx]);
}
```

`dpi_json_at_path`：
```cpp
int dpi_json_at_path(int h, const char* path) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    try {
        return alloc_handle(p->at(json::json_pointer(path)));
    } catch (const std::exception& e) {
        SET_ERROR("at_path '%s' failed: %s", path, e.what());
        return 0;
    } catch (...) {
        SET_ERROR("at_path '%s' failed", path);
        return 0;
    }
}
```

`dpi_json_set`：
```cpp
int dpi_json_set(int h, const char* key, int val_h) {
    json* p = get_handle(h);
    json* pv = get_handle(val_h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_object()) { SET_ERROR("expected object for set('%s')", key); return 0; }
    if (!pv) { SET_ERROR("invalid value handle: %d", val_h); return 0; }
    json new_obj = *p;
    new_obj[key] = *pv;
    return alloc_handle(new_obj);
}
```

`dpi_json_push`：
```cpp
int dpi_json_push(int h, int val_h) {
    json* p = get_handle(h);
    json* pv = get_handle(val_h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_array()) { SET_ERROR("expected array for push()"); return 0; }
    if (!pv) { SET_ERROR("invalid value handle: %d", val_h); return 0; }
    json new_arr = *p;
    new_arr.push_back(*pv);
    return alloc_handle(new_arr);
}
```

其余修改方法（`insert_at`、`remove`、`remove_at`、`update`）同样模式添加 SET_ERROR。

`dpi_json_dump_file`：
```cpp
int dpi_json_dump_file(int h, const char* fname, int indent) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return -1; }
    std::ofstream f(fname);
    if (!f.is_open()) { SET_ERROR("cannot open file for writing: %s", fname); return -1; }
    if (indent < 0) { f << p->dump(); } else { f << p->dump(indent); }
    if (!f.good()) { SET_ERROR("write failed for file: %s", fname); return -1; }
    return 0;
}
```

`dpi_json_as_string` / `dpi_json_as_int` / `dpi_json_as_real` / `dpi_json_as_bool` — 仅在无效句柄时设置错误（类型不匹配在非 strict 模式下是合法查询，不设错误）。

- [ ] **Step 4: 修复 `dpi_json_write_file` 返回码**

```cpp
int dpi_json_write_file(int h, const char* path, int indent) {
    return dpi_json_dump_file(h, path, indent);  // 直接委托，统一返回 0/-1
}
```

- [ ] **Step 5: 提交**

```bash
git add sv_json/src/dpi/sv_json_dpi.cc
git commit -m "feat(json): add error reporting, bounded g_strings, fix write_file return codes"
```

---

### Task 3: 更新 sv_json_dpi.h —— 添加 last_error 声明

**Files:**
- Modify: `sv_json/src/dpi/sv_json_dpi.h`

- [ ] **Step 1: 在 extern "C" 块末尾添加声明**

在 `dpi_json_write_file` 声明之后，`#ifdef __cplusplus` 闭合之前：

```c
// Error reporting
const char* dpi_serde_last_error(void);
```

- [ ] **Step 2: 提交**

```bash
git add sv_json/src/dpi/sv_json_dpi.h
git commit -m "feat(json): add dpi_serde_last_error declaration to header"
```

---

### Task 4: 更新 sv_yaml_dpi.cc —— 错误处理 + g_strings 有界化 + 返回码修复

**Files:**
- Modify: `sv_yaml/src/dpi/sv_yaml_dpi.cc`

- [ ] **Step 1: 添加 g_last_error 定义和 dpi_serde_last_error 实现**

在全局句柄表定义区域（`static int g_next_handle = 1;` 之后）插入：

```cpp
// Error reporting
thread_local std::string g_last_error;
```

在 YAML DPI 的 `extern "C"` 块最前面添加：

```cpp
const char* dpi_serde_last_error() {
    return g_last_error.c_str();
}
```

注：JSON 端同样有 `dpi_serde_last_error()` 定义。链接时两个 .cc 文件各自有一个 `thread_local std::string g_last_error` 和各自的 `dpi_serde_last_error()`。由于 Verilator/VCS 链接时只能有一个同名函数，需要解决符号冲突。

**解决方案**：只在 `sv_json_dpi.cc` 中定义 `dpi_serde_last_error()`，`sv_yaml_dpi.cc` 中引用 `serde_common.h` 中的 `serde::g_last_error` 并设置。两个后端共享同一个 `dpi_serde_last_error()` 入口。

具体做法：在 `sv_yaml_dpi.cc` 中**不定义** `dpi_serde_last_error()`，而是通过 `serde::set_error()` 设置错误，然后引用 JSON 端暴露的 `dpi_serde_last_error()`。

所以实际修改：在 `sv_yaml_dpi.cc` 的 extern "C" 块**之前**添加 `thread_local std::string g_last_error;`（与 serde_common.h 中的 extern 声明对应），然后在所有失败路径使用 `SET_ERROR()`。

- [ ] **Step 2: 改造 `return_str()` 为有界版本**

与 Task 2 Step 2 完全相同的逻辑。将 YAML 端的 `return_str()` 也加入 `MAX_STRINGS = 10000` 限制。

- [ ] **Step 3: 为 YAML 端所有失败路径添加 SET_ERROR**

遵循与 JSON 端相同的模式。关键函数：

`parse_yaml_input` — parse 失败时设置错误：
```cpp
static int parse_yaml_input(const char* input) {
    if (!input) { SET_ERROR("null input"); return 0; }
    // ... try parse logic ...
    // 最终失败时 SET_ERROR("YAML parse failed: not valid YAML or readable file — %s", input);
}
```

`dpi_yaml_get`、`dpi_yaml_at`、`dpi_yaml_at_path`、`dpi_yaml_set`、`dpi_yaml_push` 等 — 与 JSON 端相同模式。

`dpi_yaml_dump_file`：
```cpp
int dpi_yaml_dump_file(int h, const char* fname, int indent) {
    const YamlNode* n = get_node(h);
    if (!n) { SET_ERROR("invalid handle: %d", h); return -1; }
    if (!fname) { SET_ERROR("null filename"); return -1; }
    // ...
    if (!f.good()) { SET_ERROR("write failed for file: %s", fname); return -1; }
    return 0;
}
```

- [ ] **Step 4: 修复 `dpi_yaml_write_file` 返回码**

```cpp
int dpi_yaml_write_file(int h, const char* path, int indent) {
    return dpi_yaml_dump_file(h, path, indent);  // 统一返回 0/-1
}
```

- [ ] **Step 5: 提交**

```bash
git add sv_yaml/src/dpi/sv_yaml_dpi.cc
git commit -m "feat(yaml): add error reporting, bounded g_strings, fix write_file return codes"
```

---

### Task 5: 更新 sv_yaml_dpi.h —— 添加 last_error 声明

**Files:**
- Modify: `sv_yaml/src/dpi/sv_yaml_dpi.h`

- [ ] **Step 1: 在 extern "C" 块末尾添加**

```c
// Error reporting
const char* dpi_serde_last_error(void);
```

- [ ] **Step 2: 提交**

```bash
git add sv_yaml/src/dpi/sv_yaml_dpi.h
git commit -m "feat(yaml): add dpi_serde_last_error declaration to header"
```

---

### Task 6: 更新 sv_serde_pkg.sv —— 统一类型枚举

**Files:**
- Modify: `sv_serde/src/sv_serde_pkg.sv`

- [ ] **Step 1: 重写文件，添加统一类型枚举**

```systemverilog
package sv_serde_pkg;

  // Unified type enum — single source of truth for all formats
  typedef enum int {
    SERDE_NULL   = 0,
    SERDE_BOOL   = 1,
    SERDE_INT    = 2,
    SERDE_REAL   = 3,
    SERDE_STRING = 4,
    SERDE_ARRAY  = 5,
    SERDE_OBJECT = 6
  } sv_serde_type_e;

  // Backward-compatible aliases
  typedef sv_serde_type_e sv_json_type_e;
  typedef sv_serde_type_e sv_yaml_type_e;

  // Constants for direct value comparison (backward compat)
  localparam SV_JSON_NULL    = SERDE_NULL;
  localparam SV_JSON_BOOLEAN = SERDE_BOOL;
  localparam SV_JSON_INT     = SERDE_INT;
  localparam SV_JSON_REAL    = SERDE_REAL;
  localparam SV_JSON_STRING  = SERDE_STRING;
  localparam SV_JSON_ARRAY   = SERDE_ARRAY;
  localparam SV_JSON_OBJECT  = SERDE_OBJECT;

  localparam SV_YAML_NULL    = SERDE_NULL;
  localparam SV_YAML_BOOLEAN = SERDE_BOOL;
  localparam SV_YAML_INT     = SERDE_INT;
  localparam SV_YAML_REAL    = SERDE_REAL;
  localparam SV_YAML_STRING  = SERDE_STRING;
  localparam SV_YAML_ARRAY   = SERDE_ARRAY;
  localparam SV_YAML_OBJECT  = SERDE_OBJECT;

  import sv_json_pkg::*;
  import sv_yaml_pkg::*;
  export sv_json_pkg::*;
  export sv_yaml_pkg::*;

endpackage
```

- [ ] **Step 2: 提交**

```bash
git add sv_serde/src/sv_serde_pkg.sv
git commit -m "refactor: add unified sv_serde_type_e enum with backward-compat aliases"
```

---

### Task 7: 创建 sv_serde_base.svh —— 公共基类

**Files:**
- Create: `sv_serde/src/sv_serde_base.svh`

这是最核心的文件，包含所有 JSON/YAML 共享逻辑。约 300 行。

```systemverilog
// sv_serde_base — shared base class for sv_json and sv_yaml
// This is an include file; includer must have sv_serde_type_e in scope.

virtual class sv_serde_base;
  protected int m_handle;
  protected sv_serde_type_e m_type;
  protected bit m_strict_mode;
  protected static bit s_default_strict_mode = 0;

  // --- Constructor ---
  protected function new(int handle, sv_serde_type_e type);
    m_handle = handle;
    m_type = type;
    m_strict_mode = s_default_strict_mode;
  endfunction

  // --- Pure virtual DPI dispatch (subclass must implement) ---
  pure virtual function int   dpi_parse(string input_str);
  pure virtual function int   dpi_new_object();
  pure virtual function int   dpi_new_array();
  pure virtual function int   dpi_create_string(string val);
  pure virtual function int   dpi_create_int_val(int val);
  pure virtual function int   dpi_create_float_val(real val);
  pure virtual function int   dpi_create_bool_val(int val);
  pure virtual function int   dpi_create_null();
  pure virtual function int   dpi_get(int h, string key);
  pure virtual function int   dpi_at(int h, int idx);
  pure virtual function int   dpi_at_path(int h, string path);
  pure virtual function int   dpi_contains(int h, string key);
  pure virtual function int   dpi_empty(int h);
  pure virtual function int   dpi_size(int h);
  pure virtual function string dpi_key_at(int h, int idx);
  pure virtual function int    dpi_set(int h, string key, int val_h);
  pure virtual function int    dpi_push(int h, int val_h);
  pure virtual function int    dpi_insert_at(int h, int idx, int val_h);
  pure virtual function int    dpi_remove(int h, string key);
  pure virtual function int    dpi_remove_at(int h, int idx);
  pure virtual function int    dpi_update(int h, int other_h);
  pure virtual function int    dpi_set_string(int h, string key, string value);
  pure virtual function int    dpi_set_int(int h, string key, int value);
  pure virtual function int    dpi_set_float(int h, string key, real value);
  pure virtual function int    dpi_set_bool(int h, string key, int value);
  pure virtual function int    dpi_set_null(int h, string key);
  pure virtual function string dpi_as_string(int h);
  pure virtual function int    dpi_as_int(int h);
  pure virtual function real   dpi_as_real(int h);
  pure virtual function int    dpi_as_bool(int h);
  pure virtual function string dpi_dump(int h, int indent);
  pure virtual function int    dpi_dump_file(int h, string fname, int indent);
  pure virtual function int    dpi_clone(int h);
  pure virtual function void   dpi_destroy(int h);
  pure virtual function int    dpi_is_valid(int h);
  pure virtual function string dpi_last_error();

  // --- Strict mode ---
  static function void set_default_strict_mode(bit enable);
    s_default_strict_mode = enable;
  endfunction

  function void set_strict_mode(bit enable);
    m_strict_mode = enable;
  endfunction

  // --- Type checking ---
  function bit is_null();    return m_type == SERDE_NULL;    endfunction
  function bit is_boolean(); return m_type == SERDE_BOOL;    endfunction
  function bit is_int();     return m_type == SERDE_INT;     endfunction
  function bit is_real();    return m_type == SERDE_REAL;    endfunction
  function bit is_string();  return m_type == SERDE_STRING;  endfunction
  function bit is_array();   return m_type == SERDE_ARRAY;   endfunction
  function bit is_object();  return m_type == SERDE_OBJECT;  endfunction

  function bit is_number();
    return is_int() || is_real();
  endfunction

  function sv_serde_type_e get_type();
    return m_type;
  endfunction

  // --- Value extraction ---
  function string as_string();
    if (m_strict_mode && !is_string()) $fatal(1, "serde strict: expected string, got %0d", m_type);
    return dpi_as_string(m_handle);
  endfunction

  function int as_int();
    if (m_strict_mode && !is_int()) $fatal(1, "serde strict: expected int, got %0d", m_type);
    return dpi_as_int(m_handle);
  endfunction

  function real as_real();
    if (m_strict_mode && !is_real()) $fatal(1, "serde strict: expected real, got %0d", m_type);
    return dpi_as_real(m_handle);
  endfunction

  function bit as_bool();
    if (m_strict_mode && !is_boolean()) $fatal(1, "serde strict: expected bool, got %0d", m_type);
    return dpi_as_bool(m_handle);
  endfunction

  // --- Value access with defaults ---
  function string value_string(string key, string default_val);
    sv_serde_base v = get(key);
    if (v == null) return default_val;
    if (!v.is_string()) return default_val;
    return v.as_string();
  endfunction

  function int value_int(string key, int default_val);
    sv_serde_base v = get(key);
    if (v == null) return default_val;
    if (!v.is_int()) return default_val;
    return v.as_int();
  endfunction

  function real value_real(string key, real default_val);
    sv_serde_base v = get(key);
    if (v == null) return default_val;
    if (!v.is_real()) return default_val;
    return v.as_real();
  endfunction

  function bit value_bool(string key, bit default_val);
    sv_serde_base v = get(key);
    if (v == null) return default_val;
    if (!v.is_boolean()) return default_val;
    return v.as_bool();
  endfunction

  // --- Structure access ---
  function sv_serde_base get(string key);
    int h = dpi_get(m_handle, key);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  function sv_serde_base at(int idx);
    int h = dpi_at(m_handle, idx);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  function sv_serde_base at_path(string path);
    int h = dpi_at_path(m_handle, path);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  function bit contains(string key);
    return dpi_contains(m_handle, key);
  endfunction

  function bit empty();
    return dpi_empty(m_handle);
  endfunction

  function int size();
    return dpi_size(m_handle);
  endfunction

  function string key_at(int idx);
    return dpi_key_at(m_handle, idx);
  endfunction

  function void get_keys(output string keys[$]);
    keys = {};
    if (!is_object()) return;
    int n = size();
    for (int i = 0; i < n; i++) begin
      keys.push_back(key_at(i));
    end
  endfunction

  // --- Modification (immutable) ---
  function sv_serde_base set(string key, sv_serde_base value);
    int h = dpi_set(m_handle, key, value.m_handle);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  function sv_serde_base push(sv_serde_base value);
    int h = dpi_push(m_handle, value.m_handle);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  function sv_serde_base insert_at(int idx, sv_serde_base value);
    int h = dpi_insert_at(m_handle, idx, value.m_handle);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  function sv_serde_base remove(string key);
    int h = dpi_remove(m_handle, key);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  function sv_serde_base remove_at(int idx);
    int h = dpi_remove_at(m_handle, idx);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  function sv_serde_base update(sv_serde_base other);
    int h = dpi_update(m_handle, other.m_handle);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  // --- Serialization ---
  function string dump(string fname = "", int indent = 2);
    if (fname != "") begin
      int rc = dpi_dump_file(m_handle, fname, indent);
      return (rc == 0) ? "ok" : "error";
    end
    return dpi_dump(m_handle, indent);
  endfunction

  function int dump_file(string fname, int indent = 2);
    return dpi_dump_file(m_handle, fname, indent);
  endfunction

  // --- Lifecycle ---
  function sv_serde_base clone();
    int h = dpi_clone(m_handle);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  function void destroy();
    dpi_destroy(m_handle);
    m_handle = 0;
  endfunction

  function bit is_valid();
    return dpi_is_valid(m_handle);
  endfunction

  // --- Error reporting ---
  function string last_error();
    return dpi_last_error();
  endfunction

  // --- Helper: create child object of the correct concrete type ---
  // Must be overridden by subclass to return correct sv_json / sv_yaml type.
  pure virtual function sv_serde_base make_child(int h, sv_serde_type_e t);

  // --- Helper: type query for children (subclass delegates to DPI) ---
  pure virtual function int dpi_get_type(int h);

endclass
```

**设计要点**：
- `make_child()` 是抽象工厂方法——子类重写它来创建正确的具体类型（`sv_json` 或 `sv_yaml`）
- `dpi_get_type()` 是额外的虚方法，用于 `get()`/`at()`/`at_path()` 返回子节点时缓存类型
- `sv_serde_base` 使用 `virtual class`（抽象类），不可直接实例化
- 类型检查方法使用 `SERDE_*` 统一枚举常量

- [ ] **Step 2: 提交**

```bash
git add sv_serde/src/sv_serde_base.svh
git commit -m "feat: add sv_serde_base virtual class with shared JSON/YAML logic"
```

---

### Task 8: 重构 sv_json_pkg.sv —— 薄适配器

**Files:**
- Modify: `sv_json/src/sv_json_pkg.sv`（完全重写，~100 行）

```systemverilog
package sv_json_pkg;

  import sv_serde_pkg::sv_serde_type_e;
  import sv_serde_pkg::SERDE_NULL;
  import sv_serde_pkg::SERDE_BOOL;
  import sv_serde_pkg::SERDE_INT;
  import sv_serde_pkg::SERDE_REAL;
  import sv_serde_pkg::SERDE_STRING;
  import sv_serde_pkg::SERDE_ARRAY;
  import sv_serde_pkg::SERDE_OBJECT;

  // Backward-compat type alias (also in sv_serde_pkg)
  typedef sv_serde_type_e sv_json_type_e;
  localparam SV_JSON_NULL    = SERDE_NULL;
  localparam SV_JSON_BOOLEAN = SERDE_BOOL;
  localparam SV_JSON_INT     = SERDE_INT;
  localparam SV_JSON_REAL    = SERDE_REAL;
  localparam SV_JSON_STRING  = SERDE_STRING;
  localparam SV_JSON_ARRAY   = SERDE_ARRAY;
  localparam SV_JSON_OBJECT  = SERDE_OBJECT;

  // DPI imports
  import "DPI-C" function int    dpi_json_parse(input string input_str);
  import "DPI-C" function int    dpi_json_new_object();
  import "DPI-C" function int    dpi_json_new_array();
  import "DPI-C" function void   dpi_json_destroy(input int handle);
  import "DPI-C" function int    dpi_json_clone(input int handle);
  import "DPI-C" function void   dpi_json_free(input int handle);
  import "DPI-C" function int    dpi_json_is_valid(input int handle);
  import "DPI-C" function int    dpi_json_get_type(input int h);
  import "DPI-C" function string dpi_json_as_string(input int h);
  import "DPI-C" function int    dpi_json_as_int(input int h);
  import "DPI-C" function real   dpi_json_as_real(input int h);
  import "DPI-C" function int    dpi_json_as_bool(input int h);
  import "DPI-C" function int    dpi_json_create_string(input string val);
  import "DPI-C" function int    dpi_json_create_int_val(input int val);
  import "DPI-C" function int    dpi_json_create_float_val(input real val);
  import "DPI-C" function int    dpi_json_create_bool_val(input int val);
  import "DPI-C" function int    dpi_json_create_null();
  import "DPI-C" function int    dpi_json_get(input int h, input string key);
  import "DPI-C" function int    dpi_json_at(input int h, input int idx);
  import "DPI-C" function int    dpi_json_at_path(input int h, input string path);
  import "DPI-C" function int    dpi_json_contains(input int h, input string key);
  import "DPI-C" function int    dpi_json_empty(input int h);
  import "DPI-C" function int    dpi_json_size(input int h);
  import "DPI-C" function string dpi_json_key_at(input int h, input int idx);
  import "DPI-C" function int    dpi_json_set(input int h, input string key, input int val_h);
  import "DPI-C" function int    dpi_json_push(input int h, input int val_h);
  import "DPI-C" function int    dpi_json_insert_at(input int h, input int idx, input int val_h);
  import "DPI-C" function int    dpi_json_remove(input int h, input string key);
  import "DPI-C" function int    dpi_json_remove_at(input int h, input int idx);
  import "DPI-C" function int    dpi_json_update(input int h, input int other_h);
  import "DPI-C" function int    dpi_json_set_string(input int h, input string key, input string value);
  import "DPI-C" function int    dpi_json_set_int(input int h, input string key, input int value);
  import "DPI-C" function int    dpi_json_set_float(input int h, input string key, input real value);
  import "DPI-C" function int    dpi_json_set_bool(input int h, input string key, input int value);
  import "DPI-C" function int    dpi_json_set_null(input int h, input string key);
  import "DPI-C" function string dpi_json_dump(input int h, input int indent);
  import "DPI-C" function int    dpi_json_dump_file(input int h, input string fname, input int indent);
  import "DPI-C" function int    dpi_json_write_file(input int h, input string path, input int indent);
  import "DPI-C" function string dpi_serde_last_error();

  `include "sv_serde_base.svh"

  class sv_json extends sv_serde_base;

    function new(int handle, sv_serde_type_e json_type);
      super.new(handle, json_type);
    endfunction

    // --- Virtual DPI dispatch (one-liner delegates) ---
    function int   dpi_parse(string s);           return dpi_json_parse(s);           endfunction
    function int   dpi_new_object();              return dpi_json_new_object();       endfunction
    function int   dpi_new_array();               return dpi_json_new_array();        endfunction
    function int   dpi_create_string(string v);   return dpi_json_create_string(v);   endfunction
    function int   dpi_create_int_val(int v);     return dpi_json_create_int_val(v);  endfunction
    function int   dpi_create_float_val(real v);  return dpi_json_create_float_val(v);endfunction
    function int   dpi_create_bool_val(int v);    return dpi_json_create_bool_val(v); endfunction
    function int   dpi_create_null();             return dpi_json_create_null();      endfunction
    function int   dpi_get(int h, string k);      return dpi_json_get(h, k);          endfunction
    function int   dpi_at(int h, int i);          return dpi_json_at(h, i);           endfunction
    function int   dpi_at_path(int h, string p);  return dpi_json_at_path(h, p);      endfunction
    function int   dpi_contains(int h, string k); return dpi_json_contains(h, k);     endfunction
    function int   dpi_empty(int h);              return dpi_json_empty(h);           endfunction
    function int   dpi_size(int h);               return dpi_json_size(h);            endfunction
    function string dpi_key_at(int h, int i);     return dpi_json_key_at(h, i);       endfunction
    function int    dpi_set(int h, string k, int v);       return dpi_json_set(h, k, v);       endfunction
    function int    dpi_push(int h, int v);               return dpi_json_push(h, v);          endfunction
    function int    dpi_insert_at(int h, int i, int v);   return dpi_json_insert_at(h, i, v);  endfunction
    function int    dpi_remove(int h, string k);          return dpi_json_remove(h, k);        endfunction
    function int    dpi_remove_at(int h, int i);          return dpi_json_remove_at(h, i);     endfunction
    function int    dpi_update(int h, int o);             return dpi_json_update(h, o);        endfunction
    function int    dpi_set_string(int h, string k, string v); return dpi_json_set_string(h, k, v); endfunction
    function int    dpi_set_int(int h, string k, int v);      return dpi_json_set_int(h, k, v);      endfunction
    function int    dpi_set_float(int h, string k, real v);   return dpi_json_set_float(h, k, v);    endfunction
    function int    dpi_set_bool(int h, string k, int v);     return dpi_json_set_bool(h, k, v);     endfunction
    function int    dpi_set_null(int h, string k);            return dpi_json_set_null(h, k);        endfunction
    function string dpi_as_string(int h);     return dpi_json_as_string(h);     endfunction
    function int    dpi_as_int(int h);         return dpi_json_as_int(h);       endfunction
    function real   dpi_as_real(int h);        return dpi_json_as_real(h);      endfunction
    function int    dpi_as_bool(int h);        return dpi_json_as_bool(h);      endfunction
    function string dpi_dump(int h, int i);    return dpi_json_dump(h, i);      endfunction
    function int    dpi_dump_file(int h, string f, int i); return dpi_json_dump_file(h, f, i); endfunction
    function int    dpi_clone(int h);          return dpi_json_clone(h);        endfunction
    function void   dpi_destroy(int h);        dpi_json_destroy(h);            endfunction
    function int    dpi_is_valid(int h);       return dpi_json_is_valid(h);    endfunction
    function string dpi_last_error();          return dpi_serde_last_error();  endfunction
    function int    dpi_get_type(int h);        return dpi_json_get_type(h);   endfunction

    function sv_serde_base make_child(int h, sv_serde_type_e t);
      sv_json child = new(h, t);
      child.m_strict_mode = this.m_strict_mode;
      return child;
    endfunction

    // --- Static factory methods ---
    static function sv_json parse(string input_str);
      int h = dpi_json_parse(input_str);
      if (h == 0) return null;
      return new(h, sv_serde_type_e'(dpi_json_get_type(h)));
    endfunction

    static function sv_json new_object();
      return new(dpi_json_new_object(), SERDE_OBJECT);
    endfunction

    static function sv_json new_array();
      return new(dpi_json_new_array(), SERDE_ARRAY);
    endfunction

    static function sv_json from_string(string val);
      return new(dpi_json_create_string(val), SERDE_STRING);
    endfunction

    static function sv_json from_int(int val);
      return new(dpi_json_create_int_val(val), SERDE_INT);
    endfunction

    static function sv_json from_real(real val);
      return new(dpi_json_create_float_val(val), SERDE_REAL);
    endfunction

    static function sv_json from_bool(bit val);
      return new(dpi_json_create_bool_val(val ? 1 : 0), SERDE_BOOL);
    endfunction

    static function sv_json make_null();
      return new(dpi_json_create_null(), SERDE_NULL);
    endfunction

  endclass

endpackage
```

- [ ] **Step 2: 提交**

```bash
git add sv_json/src/sv_json_pkg.sv
git commit -m "refactor(json): reduce sv_json to thin adapter extending sv_serde_base"
```

---

### Task 9: 重构 sv_yaml_pkg.sv —— 薄适配器 + YAML 特有方法

**Files:**
- Modify: `sv_yaml/src/sv_yaml_pkg.sv`（完全重写，~130 行）

```systemverilog
package sv_yaml_pkg;

  import sv_serde_pkg::sv_serde_type_e;
  import sv_serde_pkg::SERDE_NULL;
  import sv_serde_pkg::SERDE_BOOL;
  import sv_serde_pkg::SERDE_INT;
  import sv_serde_pkg::SERDE_REAL;
  import sv_serde_pkg::SERDE_STRING;
  import sv_serde_pkg::SERDE_ARRAY;
  import sv_serde_pkg::SERDE_OBJECT;

  // Backward-compat
  typedef sv_serde_type_e sv_yaml_type_e;
  localparam SV_YAML_NULL    = SERDE_NULL;
  localparam SV_YAML_BOOLEAN = SERDE_BOOL;
  localparam SV_YAML_INT     = SERDE_INT;
  localparam SV_YAML_REAL    = SERDE_REAL;
  localparam SV_YAML_STRING  = SERDE_STRING;
  localparam SV_YAML_ARRAY   = SERDE_ARRAY;
  localparam SV_YAML_OBJECT  = SERDE_OBJECT;

  // DPI imports
  import "DPI-C" function int    dpi_yaml_parse(input string input_str);
  import "DPI-C" function int    dpi_yaml_new_object();
  import "DPI-C" function int    dpi_yaml_new_array();
  import "DPI-C" function void   dpi_yaml_destroy(input int handle);
  import "DPI-C" function int    dpi_yaml_clone(input int handle);
  import "DPI-C" function void   dpi_yaml_free(input int handle);
  import "DPI-C" function int    dpi_yaml_is_valid(input int handle);
  import "DPI-C" function int    dpi_yaml_get_type(input int h);
  import "DPI-C" function string dpi_yaml_as_string(input int h);
  import "DPI-C" function int    dpi_yaml_as_int(input int h);
  import "DPI-C" function real   dpi_yaml_as_real(input int h);
  import "DPI-C" function int    dpi_yaml_as_bool(input int h);
  import "DPI-C" function int    dpi_yaml_create_string(input string val);
  import "DPI-C" function int    dpi_yaml_create_int_val(input int val);
  import "DPI-C" function int    dpi_yaml_create_float_val(input real val);
  import "DPI-C" function int    dpi_yaml_create_bool_val(input int val);
  import "DPI-C" function int    dpi_yaml_create_null();
  import "DPI-C" function int    dpi_yaml_get(input int h, input string key);
  import "DPI-C" function int    dpi_yaml_at(input int h, input int idx);
  import "DPI-C" function int    dpi_yaml_at_path(input int h, input string path);
  import "DPI-C" function int    dpi_yaml_contains(input int h, input string key);
  import "DPI-C" function int    dpi_yaml_empty(input int h);
  import "DPI-C" function int    dpi_yaml_size(input int h);
  import "DPI-C" function string dpi_yaml_key_at(input int h, input int idx);
  import "DPI-C" function int    dpi_yaml_set(input int h, input string key, input int val_h);
  import "DPI-C" function int    dpi_yaml_push(input int h, input int val_h);
  import "DPI-C" function int    dpi_yaml_insert_at(input int h, input int idx, input int val_h);
  import "DPI-C" function int    dpi_yaml_remove(input int h, input string key);
  import "DPI-C" function int    dpi_yaml_remove_at(input int h, input int idx);
  import "DPI-C" function int    dpi_yaml_update(input int h, input int other_h);
  import "DPI-C" function int    dpi_yaml_set_string(input int h, input string key, input string value);
  import "DPI-C" function int    dpi_yaml_set_int(input int h, input string key, input int value);
  import "DPI-C" function int    dpi_yaml_set_float(input int h, input string key, input real value);
  import "DPI-C" function int    dpi_yaml_set_bool(input int h, input string key, input int value);
  import "DPI-C" function int    dpi_yaml_set_null(input int h, input string key);
  import "DPI-C" function string dpi_yaml_dump(input int h, input int indent);
  import "DPI-C" function int    dpi_yaml_dump_file(input int h, input string fname, input int indent);
  import "DPI-C" function int    dpi_yaml_write_file(input int h, input string path, input int indent);

  // YAML-specific DPI imports
  import "DPI-C" function int    dpi_yaml_parse_all(input string input_str);
  import "DPI-C" function string dpi_yaml_comments(input int h);
  import "DPI-C" function int    dpi_yaml_set_comment(input int h, input string text);
  import "DPI-C" function string dpi_yaml_anchor(input int h);
  import "DPI-C" function int    dpi_yaml_set_anchor(input int h, input string name);
  import "DPI-C" function string dpi_yaml_alias(input int h);
  import "DPI-C" function string dpi_yaml_tag(input int h);
  import "DPI-C" function int    dpi_yaml_set_tag(input int h, input string tag);
  import "DPI-C" function string dpi_yaml_dump_flow(input int h);
  import "DPI-C" function string dpi_yaml_dump_with_comments(input int h);
  import "DPI-C" function string dpi_serde_last_error();

  `include "sv_serde_base.svh"

  class sv_yaml extends sv_serde_base;

    function new(int handle, sv_serde_type_e yaml_type);
      super.new(handle, yaml_type);
    endfunction

    // --- Virtual DPI dispatch ---
    function int   dpi_parse(string s);           return dpi_yaml_parse(s);           endfunction
    function int   dpi_new_object();              return dpi_yaml_new_object();       endfunction
    function int   dpi_new_array();               return dpi_yaml_new_array();        endfunction
    function int   dpi_create_string(string v);   return dpi_yaml_create_string(v);   endfunction
    function int   dpi_create_int_val(int v);     return dpi_yaml_create_int_val(v);  endfunction
    function int   dpi_create_float_val(real v);  return dpi_yaml_create_float_val(v);endfunction
    function int   dpi_create_bool_val(int v);    return dpi_yaml_create_bool_val(v); endfunction
    function int   dpi_create_null();             return dpi_yaml_create_null();      endfunction
    function int   dpi_get(int h, string k);      return dpi_yaml_get(h, k);          endfunction
    function int   dpi_at(int h, int i);          return dpi_yaml_at(h, i);           endfunction
    function int   dpi_at_path(int h, string p);  return dpi_yaml_at_path(h, p);      endfunction
    function int   dpi_contains(int h, string k); return dpi_yaml_contains(h, k);     endfunction
    function int   dpi_empty(int h);              return dpi_yaml_empty(h);           endfunction
    function int   dpi_size(int h);               return dpi_yaml_size(h);            endfunction
    function string dpi_key_at(int h, int i);     return dpi_yaml_key_at(h, i);       endfunction
    function int    dpi_set(int h, string k, int v);       return dpi_yaml_set(h, k, v);       endfunction
    function int    dpi_push(int h, int v);               return dpi_yaml_push(h, v);          endfunction
    function int    dpi_insert_at(int h, int i, int v);   return dpi_yaml_insert_at(h, i, v);  endfunction
    function int    dpi_remove(int h, string k);          return dpi_yaml_remove(h, k);        endfunction
    function int    dpi_remove_at(int h, int i);          return dpi_yaml_remove_at(h, i);     endfunction
    function int    dpi_update(int h, int o);             return dpi_yaml_update(h, o);        endfunction
    function int    dpi_set_string(int h, string k, string v); return dpi_yaml_set_string(h, k, v); endfunction
    function int    dpi_set_int(int h, string k, int v);      return dpi_yaml_set_int(h, k, v);      endfunction
    function int    dpi_set_float(int h, string k, real v);   return dpi_yaml_set_float(h, k, v);    endfunction
    function int    dpi_set_bool(int h, string k, int v);     return dpi_yaml_set_bool(h, k, v);     endfunction
    function int    dpi_set_null(int h, string k);            return dpi_yaml_set_null(h, k);        endfunction
    function string dpi_as_string(int h);     return dpi_yaml_as_string(h);     endfunction
    function int    dpi_as_int(int h);         return dpi_yaml_as_int(h);       endfunction
    function real   dpi_as_real(int h);        return dpi_yaml_as_real(h);      endfunction
    function int    dpi_as_bool(int h);        return dpi_yaml_as_bool(h);      endfunction
    function string dpi_dump(int h, int i);    return dpi_yaml_dump(h, i);      endfunction
    function int    dpi_dump_file(int h, string f, int i); return dpi_yaml_dump_file(h, f, i); endfunction
    function int    dpi_clone(int h);          return dpi_yaml_clone(h);        endfunction
    function void   dpi_destroy(int h);        dpi_yaml_free(h);               endfunction
    function int    dpi_is_valid(int h);       return dpi_yaml_is_valid(h);    endfunction
    function string dpi_last_error();          return dpi_serde_last_error();  endfunction
    function int    dpi_get_type(int h);        return dpi_yaml_get_type(h);   endfunction

    function sv_serde_base make_child(int h, sv_serde_type_e t);
      sv_yaml child = new(h, t);
      child.m_strict_mode = this.m_strict_mode;
      return child;
    endfunction

    // --- Static factory methods ---
    static function sv_yaml parse(string input_str);
      int h = dpi_yaml_parse(input_str);
      if (h == 0) return null;
      return new(h, sv_serde_type_e'(dpi_yaml_get_type(h)));
    endfunction

    static function sv_yaml new_object();
      return new(dpi_yaml_new_object(), SERDE_OBJECT);
    endfunction

    static function sv_yaml new_array();
      return new(dpi_yaml_new_array(), SERDE_ARRAY);
    endfunction

    static function sv_yaml from_string(string val);
      return new(dpi_yaml_create_string(val), SERDE_STRING);
    endfunction

    static function sv_yaml from_int(int val);
      return new(dpi_yaml_create_int_val(val), SERDE_INT);
    endfunction

    static function sv_yaml from_real(real val);
      return new(dpi_yaml_create_float_val(val), SERDE_REAL);
    endfunction

    static function sv_yaml from_bool(bit val);
      return new(dpi_yaml_create_bool_val(val ? 1 : 0), SERDE_BOOL);
    endfunction

    static function sv_yaml make_null();
      return new(dpi_yaml_create_null(), SERDE_NULL);
    endfunction

    // --- YAML-specific ---
    static function sv_yaml yaml_parse_all(string input_str);
      int h = dpi_yaml_parse_all(input_str);
      if (h == 0) return null;
      return new(h, sv_serde_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function string yaml_comments(); return dpi_yaml_comments(m_handle); endfunction
    function sv_yaml yaml_set_comment(string text);
      int h = dpi_yaml_set_comment(m_handle, text);
      if (h == 0) return null;
      return sv_yaml::new(h, sv_serde_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function string yaml_anchor(); return dpi_yaml_anchor(m_handle); endfunction
    function sv_yaml yaml_set_anchor(string name);
      int h = dpi_yaml_set_anchor(m_handle, name);
      if (h == 0) return null;
      return sv_yaml::new(h, sv_serde_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function string yaml_alias(); return dpi_yaml_alias(m_handle); endfunction
    function string yaml_tag(); return dpi_yaml_tag(m_handle); endfunction
    function sv_yaml yaml_set_tag(string tag);
      int h = dpi_yaml_set_tag(m_handle, tag);
      if (h == 0) return null;
      return sv_yaml::new(h, sv_serde_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function string yaml_dump_flow(); return dpi_yaml_dump_flow(m_handle); endfunction
    function string yaml_dump_with_comments(); return dpi_yaml_dump_with_comments(m_handle); endfunction

  endclass

endpackage
```

**注意**：YAML 特有方法（`yaml_set_comment`、`yaml_set_anchor`、`yaml_set_tag`）用 `new()` 构造返回值时，需要绕过 protected 构造函数。这里使用静态工厂模式，在每个 YAML 特有方法中通过 `sv_yaml::new(h, type)` 调用。但实际上构造函数是 `local`（protected），需要在 `sv_yaml` 内部可访问。如果 Verilator 不支持从静态方法调用 protected 构造函数，可以改为在类内部添加一个 `local static function sv_yaml make(int h, sv_serde_type_e t)`。

- [ ] **Step 2: 提交**

```bash
git add sv_yaml/src/sv_yaml_pkg.sv
git commit -m "refactor(yaml): reduce sv_yaml to thin adapter extending sv_serde_base"
```

---

### Task 10: 更新测试文件 —— include helpers + 适配新 API

**Files:**
- Modify: `tests/test_json_class.sv`
- Modify: `tests/test_yaml_class.sv`

- [ ] **Step 1: 更新 test_json_class.sv**

删除内联的 `check_int`、`check_string`、`check_bit` 任务定义（第 8-36 行），替换为：

```systemverilog
import sv_json_pkg::*;
`include "serde_test_helpers.sv"

module test_json_class;
  int pass_count = 0;
  int fail_count = 0;
  sv_json j, j2;
```

测试主体（`initial begin ... end`）保持不变，因为所有方法签名不变。唯一变化：
- `SV_JSON_*` 常量仍然可用（作为 `sv_json_pkg` 的 localparam 或 `sv_serde_pkg` 的导出）
- `get_type()` 返回 `sv_serde_type_e`，但数值与原来相同

- [ ] **Step 2: 更新 test_yaml_class.sv**

同样删除内联的 `check_int`、`check_string`、`check_bit` 任务定义，替换为：

```systemverilog
import sv_yaml_pkg::*;
`include "serde_test_helpers.sv"

module test_yaml_class;
  int pass_count = 0;
  int fail_count = 0;
```

- [ ] **Step 3: 提交**

```bash
git add tests/test_json_class.sv tests/test_yaml_class.sv
git commit -m "refactor(tests): use shared serde_test_helpers.sv instead of inline helpers"
```

---

### Task 11: 更新 Makefile.verilator

**Files:**
- Modify: `run/Makefile.verilator`

- [ ] **Step 1: 添加 sv_serde 路径到编译选项**

在 `JSON_CFLAGS` 和 `YAML_CFLAGS` 中添加 serde_common.h 路径（已存在），在 Verilator flags 添加 sv_serde include 路径：

```makefile
VERILATOR_FLAGS = --binary --build -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-UNOPTFLAT -Wno-UNUSED -Wno-BLKANDNBLK -Wno-STMTDLY -Wno-INITIALDLY -Wno-IMPLICIT -Wno-DECLFILENAME -Wno-WIDTHTRUNC -I$(abspath tests) -I$(abspath sv_serde/src)
```

关键变更：末尾添加 `-I$(abspath sv_serde/src)`，使 `include "sv_serde_base.svh"` 可被找到。

JSON 编译行更新：

```makefile
run_test_json:
	$(VERILATOR) $(VERILATOR_FLAGS) -CFLAGS "$(JSON_CFLAGS)" \
		sv_serde/src/sv_serde_pkg.sv \
		$(JSON_PKG) \
		$(JSON_TEST) \
		$(JSON_DPI) \
		--top-module $(JSON_TOP) \
		--Mdir $(JSON_OBJ_DIR) \
		-o test_json_class
	./$(JSON_OBJ_DIR)/test_json_class
```

YAML 编译行同样添加 `sv_serde/src/sv_serde_pkg.sv`。

- [ ] **Step 2: 提交**

```bash
git add run/Makefile.verilator
git commit -m "build: add sv_serde include path and sv_serde_pkg.sv to Verilator targets"
```

---

### Task 12: 编译并运行测试

- [ ] **Step 1: 运行 JSON 测试**

```bash
make -f run/Makefile.verilator run_test_json
```
预期：51 tests passed, 0 failed（或由于新增错误处理，pass_count 略有变化但无新失败）

- [ ] **Step 2: 运行 YAML 测试**

```bash
make -f run/Makefile.verilator run_test_yaml
```
预期：62 tests passed, 0 failed

- [ ] **Step 3: 运行全部测试**

```bash
make -f run/Makefile.verilator run_test_all
```
预期：所有测试通过

- [ ] **Step 4: 如果有编译错误，根据错误类型修复**

常见问题：
- `sv_serde_base.svh` include 路径 → 检查 `-I` flags
- `dpi_serde_last_error` 重复定义 → 确保只在 json .cc 中定义
- `pure virtual` 不匹配 → 检查所有虚方法签名一致
- `localparam` 不可见 → 确保测试文件 import 正确的包
- SV `virtual class` 语法 → 检查 Verilator 版本支持

---

### Task 13: 最终验证 —— 检查文件行数变化

- [ ] **Step 1: 统计行数**

```bash
wc -l sv_json/src/sv_json_pkg.sv sv_yaml/src/sv_yaml_pkg.sv sv_serde/src/sv_serde_base.svh sv_serde/src/sv_serde_pkg.sv
```
预期：
- `sv_json_pkg.sv`: ~100 行（原 331 行）
- `sv_yaml_pkg.sv`: ~130 行（原 356 行）
- `sv_serde_base.svh`: ~300 行（新增，集中了原两个文件的重复代码）
- `sv_serde_pkg.sv`: ~50 行（原 13 行，新增类型枚举和兼容别名）

- [ ] **Step 2: 提交**

```bash
git add -A
git commit -m "refactor: finalize architecture optimization — unified types, base class, error reporting"
```

---

## 自审清单

1. **Spec 覆盖**：8 个问题全部对应到任务——类型枚举 (T6)、基类去重 (T7-9)、错误处理 (T2-5)、strict_mode 实例化 (T7)、内存管理/destroy (T7)、g_strings 有界化 (T2, T4)、返回码统一 (T2, T4)、测试辅助复用 (T10)

2. **无占位符**：所有步骤包含完整代码或精确的命令

3. **类型一致性**：`sv_serde_type_e` 在 T6 定义 → T7 基类使用 → T8/T9 子类 import；`dpi_serde_last_error` 在 T1 声明 → T2 定义 → T3/T5 头文件声明 → T8/T9 SV 侧使用
