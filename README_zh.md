# sv_serde

SystemVerilog JSON/YAML 处理库。通过 DPI-C 在 SystemVerilog 中直接解析、查询、修改和序列化 JSON 和 YAML 数据。

[English](README.md)

## 特性

- **JSON** — 基于 [nlohmann/json](https://github.com/nlohmann/json) v3.12.0 的完整 JSON 支持
- **YAML** — 基于 [rapidyaml](https://github.com/biojppm/rapidyaml) v0.12.1 的完整 YAML 1.2 支持，包括锚点、别名、标签、多文档和注释
- **统一 API** — `sv_json` 和 `sv_yaml` 共享相同的方法名
- **不可变语义** — 所有修改操作返回新对象，原始数据不变
- **JSON Pointer** — 支持 RFC 6901 路径访问（`/foo/bar/0/baz`），JSON 和 YAML 通用
- **零依赖** — 头文件库直接嵌入仓库，无需外部工具

## 快速开始

```systemverilog
import sv_json_pkg::*;

// 解析 JSON
sv_json j = sv_json::parse("{\"name\":\"Alice\",\"scores\":[95,87,92]}");

// 查询
string name = j.get("name").as_string();           // "Alice"
int first    = j.get("scores").at(0).as_int();     // 95

// 路径访问
int score = j.at_path("/scores/1").as_int();        // 87

// 修改（返回新对象）
sv_json updated = j.set("name", sv_json::from_string("Bob"));
updated.dump("output.json");
```

```systemverilog
import sv_yaml_pkg::*;

// 解析 YAML
sv_yaml y = sv_yaml::parse("name: Alice\nscores:\n  - 95\n  - 87");

// 与 sv_json 相同的 API
string name = y.get("name").as_string();
int first   = y.get("scores").at(0).as_int();

// YAML 特有：多文档
sv_yaml docs = sv_yaml::yaml_parse_all("a: 1\n---\nb: 2");

// YAML 特有：标签
string tag = y.get("name").yaml_tag();

// YAML 特有：Flow 风格输出
string flow = y.yaml_dump_flow();
```

## 集成

### 前置要求

- 支持 DPI-C 的 SystemVerilog-2012 仿真器（VCS、Xcelium、Verilator）
- C++17 编译器（g++ 或 clang++）
- Verilator（用于本地开发/测试）

### 文件布局

将以下文件复制到你的项目中：

```
your_project/
├── sv_serde/
│   └── src/
│       └── sv_serde.sv            # 统一包（同时导入两个）
├── sv_json/
│   ├── src/
│   │   ├── sv_json_pkg.sv        # 包 + 类定义
│   │   └── dpi/
│   │       ├── sv_json_dpi.h     # C++ 头文件
│   │       ├── sv_json_dpi.cc    # C++ 实现
│   │       └── nlohmann/json.hpp # JSON 引擎（嵌入）
│   └── (tests/ — 可选)
├── sv_yaml/                       # 可选：YAML 支持
│   ├── src/
│   │   ├── sv_yaml_pkg.sv
│   │   └── dpi/
│   │       ├── sv_yaml_dpi.h
│   │       ├── sv_yaml_dpi.cc
│   │       └── rapidyaml-0.12.1.hpp
│   └── (tests/ — 可选)
```

### 导入方式

三种导入方式，按需选择：

```systemverilog
import sv_json_pkg::*;   // 仅 JSON
import sv_yaml_pkg::*;   // 仅 YAML
import sv_serde::*;       // 同时包含 JSON 和 YAML
```

### VCS

```bash
vcs -full64 -sverilog -dpiheader sv_json/src/dpi/sv_json_dpi.h \
    sv_json/src/sv_json_pkg.sv your_test.sv \
    sv_json/src/dpi/sv_json_dpi.cc \
    -o simv
./simv
```

带 YAML 支持：

```bash
vcs -full64 -sverilog \
    -dpiheader sv_json/src/dpi/sv_json_dpi.h \
    -dpiheader sv_yaml/src/dpi/sv_yaml_dpi.h \
    sv_json/src/sv_json_pkg.sv \
    sv_yaml/src/sv_yaml_pkg.sv \
    your_test.sv \
    sv_json/src/dpi/sv_json_dpi.cc \
    sv_yaml/src/dpi/sv_yaml_dpi.cc \
    -o simv
```

### Xcelium

```bash
xrun -sv -dpiheader sv_json/src/dpi/sv_json_dpi.h \
     sv_json/src/sv_json_pkg.sv your_test.sv \
     sv_json/src/dpi/sv_json_dpi.cc
```

### Verilator（仅用于测试）

```bash
make -f run/Makefile.verilator run_test_json   # JSON 测试（97 个）
make -f run/Makefile.verilator run_test_yaml   # YAML 测试（124 个）
make -f run/Makefile.verilator run_test_all    # 全部测试（221 个）
```

> **注意：** Verilator 5.x 不支持 SystemVerilog 类。测试套件直接调用 DPI 函数。`sv_json`/`sv_yaml` 类需配合 VCS 和 Xcelium 使用。

## API 参考

### 通用 API（sv_json 和 sv_yaml）

#### 解析与创建

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `::parse(string)` | object | 解析 JSON/YAML 字符串或文件路径 |
| `::new_object()` | object | 空对象 `{}` |
| `::new_array()` | object | 空数组 `[]` |
| `::from_string(string)` | object | 字符串值 |
| `::from_int(int)` | object | 整数值 |
| `::from_real(real)` | object | 浮点值 |
| `::from_bool(bit)` | object | 布尔值 |
| `::make_null()` | object | 空值 |

#### 类型检查

| 方法 | 返回值 |
|------|--------|
| `.is_null()` | `bit` |
| `.is_boolean()` | `bit` |
| `.is_int()` | `bit` |
| `.is_real()` | `bit` |
| `.is_number()` | `bit`（整数或浮点） |
| `.is_string()` | `bit` |
| `.is_array()` | `bit` |
| `.is_object()` | `bit` |

#### 值提取

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `.as_string()` | `string` | 字符串值 |
| `.as_int()` | `int` | 整数值 |
| `.as_real()` | `real` | 浮点值 |
| `.as_bool()` | `bit` | 布尔值 |
| `.value_string(key, default)` | `string` | 带默认值的字符串 |
| `.value_int(key, default)` | `int` | 带默认值的整数 |
| `.value_real(key, default)` | `real` | 带默认值的浮点数 |
| `.value_bool(key, default)` | `bit` | 带默认值的布尔值 |

#### 结构访问

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `.get(string key)` | object | 按键名获取对象成员 |
| `.at(int idx)` | object | 按索引获取数组元素 |
| `.at_path(string path)` | object | JSON Pointer 路径访问（RFC 6901） |
| `.contains(string key)` | `bit` | 检查键是否存在 |
| `.empty()` | `bit` | 是否为空 |
| `.size()` | `int` | 元素数量 |
| `.key_at(int idx)` | `string` | 按索引获取键名 |
| `.get_keys(output keys[$])` | `void` | 获取所有键名到队列 |

#### 修改（不可变）

所有修改方法返回**新对象**，原始对象不变。

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `.set(key, value)` | object | 设置键值的新对象 |
| `.push(value)` | object | 追加元素的新数组 |
| `.insert_at(idx, value)` | object | 插入元素的新数组 |
| `.remove(key)` | object | 移除键的新对象 |
| `.remove_at(idx)` | object | 移除元素的新数组 |
| `.update(other)` | object | 合并键值的新对象 |

#### 序列化

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `.dump()` | `string` | 格式化字符串 |
| `.dump("", -1)` | `string` | 紧凑字符串 |
| `.dump("file.json")` | `string` | 写入文件 |
| `.dump_file(fname, indent)` | `int` | 写入文件（成功返回 0） |

### YAML 专有 API

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `::yaml_parse_all(string)` | object | 解析所有文档（根为序列） |
| `.yaml_comments()` | `string` | 获取注释文本 |
| `.yaml_set_comment(string)` | object | 设置注释（返回新节点） |
| `.yaml_anchor()` | `string` | 获取锚点名（`&name`） |
| `.yaml_set_anchor(string)` | object | 设置锚点（返回新节点） |
| `.yaml_alias()` | `string` | 获取别名名（`*name`） |
| `.yaml_tag()` | `string` | 获取标签（`!!str`、`!!int` 等） |
| `.yaml_set_tag(string)` | object | 设置标签（返回新节点） |
| `.yaml_dump_flow()` | `string` | Flow 风格输出（`{key: value}`） |
| `.yaml_dump_with_comments()` | `string` | 保留注释的序列化 |

## 更多示例

### 从零构建 JSON

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

// 结果：{"name":"test","count":42,"active":true,"items":[1,2,3]}
string json_str = obj.dump();
```

### 遍历对象键

```systemverilog
sv_json data = sv_json::parse("{\"a\":1,\"b\":2,\"c\":3}");
string keys[$];
data.get_keys(keys);
foreach (keys[i]) begin
    $display("%s = %0d", keys[i], data.get(keys[i]).as_int());
end
```

### 嵌套路径访问

```systemverilog
sv_json root = sv_json::parse("{\"config\":{\"db\":{\"host\":\"localhost\",\"port\":3306}}}");
string host = root.at_path("/config/db/host").as_string();  // "localhost"
int port    = root.at_path("/config/db/port").as_int();     // 3306
```

### YAML 合并键和锚点

```systemverilog
sv_yaml y = sv_yaml::parse({
    "defaults: &defaults\n",
    "  color: blue\n",
    "  size: large\n",
    "item:\n",
    "  <<: *defaults\n",
    "  name: widget"
});

string color = y.get("item").get("color").as_string();  // "blue"（合并）
string name  = y.get("item").get("name").as_string();   // "widget"
```

### 带默认值的配置读取

```systemverilog
sv_json cfg = sv_json::parse("config.json");
int timeout = cfg.value_int("timeout_ms", 5000);   // 缺失时为 5000
string mode = cfg.value_string("mode", "release");  // 缺失时为 "release"
```

## 测试

```bash
# 运行全部测试
make -f run/Makefile.verilator run_test_all

# 仅运行 JSON 测试
make -f run/Makefile.verilator run_test_json

# 仅运行 YAML 测试
make -f run/Makefile.verilator run_test_yaml

# 清理构建产物
make -f run/Makefile.verilator clean
```

## 架构

```
┌─────────────────────┐    ┌─────────────────────┐
│   sv_json_pkg.sv    │    │   sv_yaml_pkg.sv    │
│   （SV 类）          │    │   （SV 类）          │
│   DPI 导入          │    │   DPI 导入          │
└─────────┬───────────┘    └─────────┬───────────┘
          │                          │
          ▼                          ▼
┌─────────────────────┐    ┌─────────────────────┐
│  sv_json_dpi.cc     │    │  sv_yaml_dpi.cc     │
│  nlohmann/json      │    │  rapidyaml          │
│  句柄表             │    │  句柄表             │
└─────────────────────┘    └─────────────────────┘
```

每种格式有独立的 C++ 引擎。对象通过整数句柄管理——SV 层从不接触原始 C++ 指针。

## 许可证

本项目嵌入了 [nlohmann/json](https://github.com/nlohmann/json)（MIT 许可证）和 [rapidyaml](https://github.com/biojppm/rapidyaml)（MIT 许可证）。
