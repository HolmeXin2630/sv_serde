# sv_serde 架构优化设计

## 目标

一次性解决当前代码库中已识别的全部架构问题，提升可维护性、可测试性和多进程安全性。

## 问题清单

1. SV 层 `sv_json` 与 `sv_yaml` 类 ~330 行代码重复（搜索替换级别）
2. `strict_mode` 是 package 级全局变量，多进程不安全
3. 错误处理链路缺失：C++ 异常信息完全丢弃，SV 层无法区分失败原因
4. `sv_json_type_e`、`sv_yaml_type_e`、`serde_common.h` 三处重复定义类型枚举
5. `dump_file` 返回 0/-1 vs `write_file` 返回 1/0，返回码语义相反
6. C++ 全局 `g_strings` 表无限增长
7. C++ 全局句柄表无锁保护（仅影响 VCS/Xcelium 多线程模式）
8. `tests/serde_test_helpers.sv` 存在但未被使用

---

## 方案 1：SV 层基类提取

### 新增 `sv_serde_base.svh`

在 `sv_serde/src/` 下新增基类 include 文件，包含所有 JSON/YAML 共用的逻辑。

**基类职责：**
- `m_handle`（int）、`m_type`（`sv_serde_type_e`）、`m_strict_mode`（bit）实例字段
- `s_default_strict_mode` 静态字段，控制新对象的初始 strict 值
- 构造函数 `new(int handle, sv_serde_type_e type)`
- 8 个类型检查方法：`is_null` ~ `is_object`，`is_number`
- `get_type()` 返回缓存的 `m_type`
- 4 个 `as_*()` 提取方法（含 strict_mode 检查逻辑）
- 4 个 `value_*()` 带默认值方法
- 7 个结构体访问器：`get`、`at`、`at_path`、`contains`、`empty`、`size`、`key_at`、`get_keys`
- 6 个修改方法：`set`、`push`、`insert_at`、`remove`、`remove_at`、`update`
- `dump`、`dump_file`、`clone`、`is_valid`、`destroy`
- `set_strict_mode(bit enable)` 实例方法
- `set_default_strict_mode(bit enable)` 静态方法
- `last_error()` 查询最近错误

**虚方法接口（子类必须重写）：**

```
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
```

### JSON/YAML 子类

`sv_json` 和 `sv_yaml` 继承基类，仅包含：
- 格式特有的 DPI import 声明
- 虚方法实现（一行委托到对应 DPI 函数）
- 8 个静态工厂方法（`parse`、`from_*`、`new_object`/`new_array`）
- YAML 特有方法（10 个）

文件从 331/356 行缩减到各约 100 行。

### 内存管理与 `destroy()`

**问题**：C++ 全局句柄表只增不减，`dpi_json_destroy`/`dpi_json_free` 虽已 import 但未暴露给用户。大量大文件场景下内存持续膨胀。

**约束**：SystemVerilog 没有析构函数，无法在对象被 GC 回收时自动触发 C++ 侧内存释放。这是语言层面的限制，所有 SV DPI 库的标准做法是提供手动释放方法。

**方案**：基类暴露 `destroy()`，用户显式调用释放 C++ 侧内存。

```systemverilog
// sv_serde_base
function void destroy();
    dpi_destroy(m_handle);  // virtual → dpi_json_destroy / dpi_yaml_free
    m_handle = 0;
endfunction
```

**使用模式**——批量大文件场景：

```systemverilog
for (int i = 0; i < 1000; i++) begin
    sv_json j = sv_json::parse(read_large_file(i));
    // ... 使用 j ...
    j.destroy();  // 立即释放 C++ 侧内存
end
```

**不可变语义下的注意事项**：链式操作产生多个中间版本，每个都占用独立 C++ 内存，需要逐一释放：

```systemverilog
sv_json a = sv_json::parse(big);   // handle=5
sv_json b = a.set("x", v);         // handle=7（深拷贝新对象）
sv_json c = b.remove("y");         // handle=9（深拷贝新对象）
a.destroy();  // 释放 handle=5
b.destroy();  // 释放 handle=7
// c 继续使用 handle=9
```

**安全性**：`destroy()` 后 `m_handle` 置为 0，后续对已销毁对象的方法调用将返回 null/0/""（通过 null handle 检测机制），不会出现悬空指针未定义行为。

---

## 方案 2：类型枚举统一

删除 `sv_json_type_e` 和 `sv_yaml_type_e`，在 `sv_serde_pkg` 中定义：

```systemverilog
typedef enum int {
    SERDE_NULL   = 0,
    SERDE_BOOL   = 1,
    SERDE_INT    = 2,
    SERDE_REAL   = 3,
    SERDE_STRING = 4,
    SERDE_ARRAY  = 5,
    SERDE_OBJECT = 6
} sv_serde_type_e;
```

`serde_common.h` 的 `SERDE_TYPE_*` 宏和 `static_assert` 保留，作为 C++ 侧唯一真相源。

---

## 方案 3：错误处理链路

### C++ 侧

- 新增 `thread_local std::string g_last_error`（或全局 + mutex）
- 暴露 `dpi_serde_last_error()` 返回最后一次错误描述
- 所有 DPI 函数失败时设置有意义的错误信息：

| 场景 | 错误信息示例 |
|------|-------------|
| parse 失败 | `"parse error: unexpected token at line 1, offset 42"` |
| key 不存在 | `"key 'foo' not found"` |
| 类型不匹配 | `"expected int, got string"` |
| 无效句柄 | `"invalid handle: 42"` |
| 索引越界 | `"index 5 out of range, size is 3"` |
| 文件 IO 失败 | `"cannot open file: /path/foo.json"` |

### SV 侧

基类中提供：

```systemverilog
function string last_error();
    return dpi_serde_last_error();
endfunction
```

不改变现有方法返回值类型。调用方在收到 null/0 后可通过 `last_error()` 获取详情。

---

## 方案 4：strict_mode 实例化

```systemverilog
class sv_serde_base;
    protected bit m_strict_mode;                    // 实例字段
    protected static bit s_default_strict_mode = 0; // 全局默认

    function new(int handle, sv_serde_type_e type);
        m_strict_mode = s_default_strict_mode;     // 构造时继承全局默认
    endfunction

    static function void set_default_strict_mode(bit enable);
        s_default_strict_mode = enable;
    endfunction

    function void set_strict_mode(bit enable);
        m_strict_mode = enable;
    endfunction
endclass
```

- 每个对象独立控制 strict_mode，多进程安全
- `set_default_strict_mode()` 控制新对象的初始值
- 删去 package 级 `bit strict_mode = 0;`

---

## 方案 5：小修小补

### 5a. dump_file / write_file 返回码统一

- `dump_file` 保持 `0`=成功 `-1`=失败
- `write_file` 改为与 `dump_file` 一致（`0`=成功 `-1`=失败）
- 长期建议：合并为一个方法，`write_file` 保留为废弃别名

### 5b. g_strings 有界化

**安全性**：SV 仿真器在 DPI 调用返回瞬间将 C 字符串拷贝为 SV 自己的 `string` 对象。`g_strings` 只在 DPI 返回的极短窗口内被读取，清除旧条目不影响 SV 侧已持有的数据。

**策略**：`g_next_str_id` 单调递增，最新条目 ID 最大。超过阈值时清除 ID 较小的一半（最早条目），确保刚存入的新条目不受影响：

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

### 5c. C++ 句柄表线程保护（可选）

VCS/Xcelium 多线程仿真模式下，对 `g_handles` 和 `g_strings` 的操作加 `std::mutex` 保护。

### 5d. 测试辅助文件

让 `test_json_class.sv` 和 `test_yaml_class.sv` include `serde_test_helpers.sv`，删除内联的 `check_*` 副本。

---

## 文件变更汇总

| 文件 | 操作 | 描述 |
|------|------|------|
| `sv_serde/src/sv_serde_base.svh` | **新增** | 公共基类，~330 行 |
| `sv_serde/src/sv_serde_pkg.sv` | 修改 | 添加统一类型枚举、include base.svh |
| `sv_serde/src/dpi/serde_common.h` | 修改 | 添加错误码宏、last_error 声明 |
| `sv_json/src/sv_json_pkg.sv` | 修改 | 缩减为薄适配器，~100 行 |
| `sv_yaml/src/sv_yaml_pkg.sv` | 修改 | 缩减为薄适配器，~110 行 |
| `sv_json/src/dpi/sv_json_dpi.cc` | 修改 | 添加错误信息设置，修复 write_file 返回码 |
| `sv_json/src/dpi/sv_json_dpi.h` | 修改 | 添加 dpi_serde_last_error 声明 |
| `sv_yaml/src/dpi/sv_yaml_dpi.cc` | 修改 | 添加错误信息设置，修复 write_file 返回码 |
| `sv_yaml/src/dpi/sv_yaml_dpi.h` | 修改 | 添加 dpi_serde_last_error 声明 |
| `tests/test_json_class.sv` | 修改 | 适配新 API，include helpers |
| `tests/test_yaml_class.sv` | 修改 | 适配新 API，include helpers |
| `tests/serde_test_helpers.sv` | 不变 | 已可正常使用 |
| `run/Makefile.verilator` | 修改 | 添加 base.svh 编译依赖 |

## 接口兼容性

- 所有 public API 保持不变（方法签名、调用方式不变）
- 新增 `destroy()` 方法，用于显式释放 C++ 侧内存（SV 语言限制，无析构函数）
- 类型枚举别名保持向后兼容（`sv_json_type_e` 可通过 typedef 指向 `sv_serde_type_e`）
- `set_strict_mode` 从包级静态改为实例方法，原有静态调用方式需要改为 `sv_json::set_default_strict_mode(1)` 或对象方法
- `strict_mode` 包级变量删除，直接引用需迁移
