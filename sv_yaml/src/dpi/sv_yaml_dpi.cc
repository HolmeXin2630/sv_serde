#include "sv_yaml_dpi.h"

#define RYML_SINGLE_HDR_DEFINE_NOW
#include "rapidyaml-0.12.1.hpp"

#include <unordered_map>
#include <string>
#include <fstream>
#include <vector>
#include <sstream>
#include <cstdlib>
#include <cstring>
#include <algorithm>
#include <thread>
#include <climits>

namespace ryml_ns = c4::yml;

// ---------------------------------------------------------------------------
// YamlNode: custom in-memory tree node
// ---------------------------------------------------------------------------
struct YamlNode {
    enum Type { NULL_VAL, BOOL_VAL, INT_VAL, REAL_VAL, STRING_VAL, MAP_VAL, SEQ_VAL };
    Type type = NULL_VAL;
    std::string str_val;
    int int_val = 0;
    double real_val = 0.0;
    bool bool_val = false;
    // For MAP: ordered list of (key_handle, value_handle)
    std::vector<std::pair<std::string, int>> map_children;
    // For SEQ: ordered list of value handles
    std::vector<int> seq_children;
    // YAML-specific metadata
    std::string comment;
    std::string anchor;
    std::string alias_name;
    std::string tag;
};

// ---------------------------------------------------------------------------
// Global handle table
// ---------------------------------------------------------------------------
static std::unordered_map<int, YamlNode> g_handles;
static int g_next_handle = 1;

static int alloc_handle(const YamlNode& n) {
    int h = g_next_handle++;
    g_handles[h] = n;
    return h;
}

static const YamlNode* get_node(int h) {
    auto it = g_handles.find(h);
    return (it != g_handles.end()) ? &it->second : nullptr;
}

// ---------------------------------------------------------------------------
// Persistent string storage for returning const char* safely
// ---------------------------------------------------------------------------
static std::unordered_map<int, std::string> g_strings;
static int g_next_str_id = 1;

static const char* return_str(const std::string& s) {
    int id = g_next_str_id++;
    g_strings[id] = s;
    return g_strings[id].c_str();
}

// ---------------------------------------------------------------------------
// rapidyaml -> YamlNode conversion
// ---------------------------------------------------------------------------
static int ryml_to_handle(const ryml_ns::Tree& tree, ryml_ns::id_type node) {
    YamlNode yn;

    if (tree.is_map(node)) {
        yn.type = YamlNode::MAP_VAL;

        // Helper: resolve a merge key's target map
        auto resolve_merge_target = [&](ryml_ns::id_type child_node) -> int {
            if (tree.is_map(child_node)) {
                return ryml_to_handle(tree, child_node);
            }
            if (tree.has_val(child_node)) {
                c4::csubstr val = tree.val(child_node);
                if (val.len > 1 && val[0] == '*') {
                    std::string anchor_name(val.str + 1, val.len - 1);
                    ryml_ns::id_type root = tree.root_id();
                    std::function<ryml_ns::id_type(ryml_ns::id_type, const std::string&)> find_anchor;
                    find_anchor = [&](ryml_ns::id_type n, const std::string& name) -> ryml_ns::id_type {
                        if (tree.has_key_anchor(n)) {
                            c4::csubstr a = tree.key_anchor(n);
                            if (std::string(a.str, a.len) == name) return n;
                        }
                        if (tree.has_val_anchor(n)) {
                            c4::csubstr a = tree.val_anchor(n);
                            if (std::string(a.str, a.len) == name) return n;
                        }
                        if (tree.has_children(n)) {
                            ryml_ns::id_type ch = tree.first_child(n);
                            while (ch != ryml_ns::NONE) {
                                ryml_ns::id_type found = find_anchor(ch, name);
                                if (found != ryml_ns::NONE) return found;
                                ch = tree.next_sibling(ch);
                            }
                        }
                        return ryml_ns::NONE;
                    };
                    ryml_ns::id_type target = find_anchor(root, anchor_name);
                    if (target != ryml_ns::NONE) {
                        return ryml_to_handle(tree, target);
                    }
                }
            }
            return 0;
        };

        // First pass: resolve merge keys (<<)
        if (tree.has_children(node)) {
            ryml_ns::id_type child = tree.first_child(node);
            while (child != ryml_ns::NONE) {
                std::string key(tree.key(child).str, tree.key(child).len);
                if (key == "<<") {
                    int merge_h = resolve_merge_target(child);
                    const YamlNode* merge_node = get_node(merge_h);
                    if (merge_node && merge_node->type == YamlNode::MAP_VAL) {
                        for (auto& p : merge_node->map_children) {
                            bool exists = false;
                            for (auto& existing : yn.map_children) {
                                if (existing.first == p.first) { exists = true; break; }
                            }
                            if (!exists) yn.map_children.push_back(p);
                        }
                    }
                }
                child = tree.next_sibling(child);
            }
        }
        // Second pass: add non-merge keys
        if (tree.has_children(node)) {
            ryml_ns::id_type child = tree.first_child(node);
            while (child != ryml_ns::NONE) {
                std::string key(tree.key(child).str, tree.key(child).len);
                if (key != "<<") {
                    int vh = ryml_to_handle(tree, child);
                    yn.map_children.push_back({key, vh});
                }
                child = tree.next_sibling(child);
            }
        }
    } else if (tree.is_seq(node)) {
        yn.type = YamlNode::SEQ_VAL;
        if (tree.has_children(node)) {
            ryml_ns::id_type child = tree.first_child(node);
            while (child != ryml_ns::NONE) {
                yn.seq_children.push_back(ryml_to_handle(tree, child));
                child = tree.next_sibling(child);
            }
        }
    } else {
        // Scalar node (keyval or val)
        c4::csubstr val;
        if (tree.has_val(node)) {
            val = tree.val(node);
        }
        yn.str_val = std::string(val.str, val.len);

        // Determine type from tag first, then from value
        bool has_val_tag = tree.has_val_tag(node);
        c4::csubstr tag;
        if (has_val_tag) tag = tree.val_tag(node);

        if (has_val_tag && tag == "!!str") {
            yn.type = YamlNode::STRING_VAL;
        } else if (has_val_tag && tag == "!!int") {
            yn.type = YamlNode::INT_VAL;
            yn.int_val = (int)strtol(val.str, nullptr, 10);
        } else if (has_val_tag && tag == "!!float") {
            yn.type = YamlNode::REAL_VAL;
            yn.real_val = strtod(val.str, nullptr);
        } else if (has_val_tag && tag == "!!bool") {
            yn.type = YamlNode::BOOL_VAL;
            yn.bool_val = (val == "true" || val == "True" || val == "TRUE" || val == "yes");
        } else if (has_val_tag && tag == "!!null") {
            yn.type = YamlNode::NULL_VAL;
        } else if (has_val_tag && tag == "!!binary") {
            yn.type = YamlNode::STRING_VAL;
        } else {
            // Infer type from value string
            if (val.empty() || val == "~" || val == "null" || val == "Null" || val == "NULL") {
                yn.type = YamlNode::NULL_VAL;
            } else if (val == "true" || val == "True" || val == "TRUE" || val == "yes" || val == "Yes" || val == "on" || val == "On") {
                yn.type = YamlNode::BOOL_VAL;
                yn.bool_val = true;
            } else if (val == "false" || val == "False" || val == "FALSE" || val == "no" || val == "No" || val == "off" || val == "Off") {
                yn.type = YamlNode::BOOL_VAL;
                yn.bool_val = false;
            } else {
                // Try integer
                char* end_i = nullptr;
                long long ival = strtoll(val.str, &end_i, 10);
                if (end_i == val.str + val.len && val.len > 0) {
                    if (ival > INT_MAX || ival < INT_MIN) {
                        yn.type = YamlNode::REAL_VAL;
                        yn.real_val = (double)ival;
                    } else {
                        yn.type = YamlNode::INT_VAL;
                        yn.int_val = (int)ival;
                    }
                } else {
                    // Try float
                    char* end_f = nullptr;
                    double dval = strtod(val.str, &end_f);
                    if (end_f == val.str + val.len && val.len > 0) {
                        yn.type = YamlNode::REAL_VAL;
                        yn.real_val = dval;
                    } else {
                        yn.type = YamlNode::STRING_VAL;
                    }
                }
            }
        }

        if (has_val_tag) {
            yn.tag = std::string(tag.str, tag.len);
        }
    }

    // Anchor (on value side)
    if (tree.has_val_anchor(node)) {
        c4::csubstr a = tree.val_anchor(node);
        yn.anchor = std::string(a.str, a.len);
    }
    // Key anchor (for map keys)
    if (tree.has_key_anchor(node)) {
        c4::csubstr a = tree.key_anchor(node);
        yn.anchor = std::string(a.str, a.len);
    }

    return alloc_handle(yn);
}

// ---------------------------------------------------------------------------
// YAML emitter: recursive string builder
// ---------------------------------------------------------------------------
static void yaml_escape_string(std::string& out, const std::string& s) {
    bool needs_quote = false;
    if (s.empty()) { needs_quote = true; }
    for (char c : s) {
        if (c == ':' || c == '#' || c == '{' || c == '}' || c == '[' || c == ']' ||
            c == ',' || c == '&' || c == '*' || c == '?' || c == '|' || c == '-' ||
            c == '<' || c == '>' || c == '=' || c == '!' || c == '%' || c == '@' ||
            c == '`' || c == '\n' || c == '\r' || c == '\t') {
            needs_quote = true;
            break;
        }
    }
    if (s == "true" || s == "True" || s == "TRUE" || s == "false" || s == "False" ||
        s == "FALSE" || s == "null" || s == "Null" || s == "NULL" || s == "yes" ||
        s == "no" || s == "on" || s == "off" || s == "~") {
        needs_quote = true;
    }
    if (s.front() == ' ' || s.back() == ' ') needs_quote = true;
    if (!s.empty() && (isdigit(s[0]) || s[0] == '-')) needs_quote = true;

    if (needs_quote) {
        out += "\"";
        for (char c : s) {
            switch (c) {
                case '"':  out += "\\\""; break;
                case '\\': out += "\\\\"; break;
                case '\n': out += "\\n"; break;
                case '\r': out += "\\r"; break;
                case '\t': out += "\\t"; break;
                default:   out += c; break;
            }
        }
        out += "\"";
    } else {
        out += s;
    }
}

static std::string emit_yaml_int(int h, int indent_level, bool flow) {
    const YamlNode* n = get_node(h);
    if (!n) return "null";
    std::string ind(indent_level * 2, ' ');
    std::string out;

    switch (n->type) {
        case YamlNode::NULL_VAL:
            out = "null";
            break;
        case YamlNode::BOOL_VAL:
            out = n->bool_val ? "true" : "false";
            break;
        case YamlNode::INT_VAL:
            out = std::to_string(n->int_val);
            break;
        case YamlNode::REAL_VAL: {
            std::ostringstream oss;
            oss << n->real_val;
            out = oss.str();
            break;
        }
        case YamlNode::STRING_VAL:
            yaml_escape_string(out, n->str_val);
            break;
        case YamlNode::MAP_VAL:
            if (flow) {
                out = "{";
                for (size_t i = 0; i < n->map_children.size(); i++) {
                    if (i > 0) out += ", ";
                    out += n->map_children[i].first + ": " +
                           emit_yaml_int(n->map_children[i].second, 0, true);
                }
                out += "}";
            } else {
                for (size_t i = 0; i < n->map_children.size(); i++) {
                    if (i > 0) out += "\n";
                    int ch = n->map_children[i].second;
                    const YamlNode* ch_n = get_node(ch);
                    bool child_is_container = ch_n && (ch_n->type == YamlNode::MAP_VAL || ch_n->type == YamlNode::SEQ_VAL);
                    if (child_is_container) {
                        out += ind + n->map_children[i].first + ":\n" +
                               emit_yaml_int(ch, indent_level + 1, false);
                    } else {
                        out += ind + n->map_children[i].first + ": " +
                               emit_yaml_int(ch, 0, false);
                    }
                }
            }
            break;
        case YamlNode::SEQ_VAL:
            if (flow) {
                out = "[";
                for (size_t i = 0; i < n->seq_children.size(); i++) {
                    if (i > 0) out += ", ";
                    out += emit_yaml_int(n->seq_children[i], 0, true);
                }
                out += "]";
            } else {
                for (size_t i = 0; i < n->seq_children.size(); i++) {
                    if (i > 0) out += "\n";
                    int ch = n->seq_children[i];
                    const YamlNode* ch_n = get_node(ch);
                    bool child_is_container = ch_n && (ch_n->type == YamlNode::MAP_VAL || ch_n->type == YamlNode::SEQ_VAL);
                    if (child_is_container) {
                        out += ind + "-\n" + emit_yaml_int(ch, indent_level + 1, false);
                    } else {
                        out += ind + "- " + emit_yaml_int(ch, 0, false);
                    }
                }
            }
            break;
    }

    // Add tag prefix for scalars
    if (!n->tag.empty() && n->type != YamlNode::MAP_VAL && n->type != YamlNode::SEQ_VAL) {
        out = n->tag + " " + out;
    }

    // Add anchor prefix
    if (!n->anchor.empty()) {
        out = "&" + n->anchor + " " + out;
    }

    return out;
}

// ---------------------------------------------------------------------------
// Parse YAML string/file via rapidyaml (try content first, then file)
// ---------------------------------------------------------------------------
static int try_parse_yaml_content(const std::string& content) {
    try {
        c4::csubstr cs = c4::to_csubstr(content);
        ryml_ns::Tree tree = ryml_ns::parse_in_arena(cs);
        ryml_ns::id_type root_id = tree.root_id();
        // For multi-doc files (--- separator), rapidyaml wraps docs in a SEQ.
        if (tree.is_seq(root_id) && tree.has_children(root_id)) {
            ryml_ns::id_type first = tree.first_child(root_id);
            if (tree.is_map(first) || (tree.is_seq(first) && tree.has_children(first))) {
                return ryml_to_handle(tree, first);
            }
        }
        // Only return non-scalar results (map/seq), not scalars
        if (tree.is_map(root_id) || tree.is_seq(root_id)) {
            return ryml_to_handle(tree, root_id);
        }
        // Scalar parsed successfully but could be a file path — signal to try file
        return -1;
    } catch (...) {
        return 0;
    }
}

static int parse_yaml_input(const char* input) {
    if (!input) return 0;
    std::string content(input);

    // First: try parsing as YAML content (non-scalar only)
    int result = try_parse_yaml_content(content);
    if (result > 0) return result;

    // Second: try as file path (also covers case where content was scalar)
    std::ifstream f(input);
    if (f.is_open()) {
        content = std::string((std::istreambuf_iterator<char>(f)),
                              std::istreambuf_iterator<char>());
        result = try_parse_yaml_content(content);
        if (result > 0) return result;
    }

    // Last resort: parse as scalar (for inline YAML like "42", "true", etc.)
    try {
        c4::csubstr cs = c4::to_csubstr(content);
        ryml_ns::Tree tree = ryml_ns::parse_in_arena(cs);
        return ryml_to_handle(tree, tree.root_id());
    } catch (...) {}
    return 0;
}

// ---------------------------------------------------------------------------
// DPI C interface
// ---------------------------------------------------------------------------

extern "C" {

// --- Object lifecycle ---

int dpi_yaml_new_object(void) {
    YamlNode n;
    n.type = YamlNode::MAP_VAL;
    return alloc_handle(n);
}

int dpi_yaml_new_array(void) {
    YamlNode n;
    n.type = YamlNode::SEQ_VAL;
    return alloc_handle(n);
}

int dpi_yaml_parse(const char* input) {
    return parse_yaml_input(input);
}

void dpi_yaml_destroy(int handle) {
    g_handles.erase(handle);
}

// --- Type checking ---

int dpi_yaml_get_type(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return -1;
    // Map C++ YamlNode::Type to SV sv_yaml_type_e values
    // C++: MAP_VAL=5, SEQ_VAL=6  SV: ARRAY=5, OBJECT=6
    switch (n->type) {
        case YamlNode::NULL_VAL:   return SV_YAML_TYPE_NULL;
        case YamlNode::BOOL_VAL:   return SV_YAML_TYPE_BOOL;
        case YamlNode::INT_VAL:    return SV_YAML_TYPE_INT;
        case YamlNode::REAL_VAL:   return SV_YAML_TYPE_FLOAT;
        case YamlNode::STRING_VAL: return SV_YAML_TYPE_STRING;
        case YamlNode::MAP_VAL:    return SV_YAML_TYPE_OBJECT;
        case YamlNode::SEQ_VAL:    return SV_YAML_TYPE_ARRAY;
        default: return -1;
    }
}

// --- Value extraction ---

const char* dpi_yaml_as_string(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return "";
    switch (n->type) {
        case YamlNode::STRING_VAL:  return return_str(n->str_val);
        case YamlNode::INT_VAL:     return return_str(std::to_string(n->int_val));
        case YamlNode::REAL_VAL: {
            std::ostringstream oss;
            oss << n->real_val;
            return return_str(oss.str());
        }
        case YamlNode::BOOL_VAL:    return return_str(n->bool_val ? "true" : "false");
        case YamlNode::NULL_VAL:    return "null";
        default:                    return "";
    }
}

int dpi_yaml_as_int(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return 0;
    switch (n->type) {
        case YamlNode::INT_VAL:   return n->int_val;
        case YamlNode::REAL_VAL:  return (int)n->real_val;
        case YamlNode::BOOL_VAL:  return n->bool_val ? 1 : 0;
        default: return 0;
    }
}

double dpi_yaml_as_real(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return 0.0;
    switch (n->type) {
        case YamlNode::REAL_VAL:  return n->real_val;
        case YamlNode::INT_VAL:   return (double)n->int_val;
        default: return 0.0;
    }
}

int dpi_yaml_as_bool(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return 0;
    switch (n->type) {
        case YamlNode::BOOL_VAL:  return n->bool_val ? 1 : 0;
        case YamlNode::INT_VAL:   return n->int_val ? 1 : 0;
        case YamlNode::STRING_VAL: return (n->str_val == "true" || n->str_val == "True") ? 1 : 0;
        default: return 0;
    }
}

// --- Create functions ---

int dpi_yaml_create_string(const char* val) {
    YamlNode n;
    n.type = YamlNode::STRING_VAL;
    n.str_val = val ? val : "";
    return alloc_handle(n);
}

int dpi_yaml_create_int_val(int val) {
    YamlNode n;
    n.type = YamlNode::INT_VAL;
    n.int_val = val;
    return alloc_handle(n);
}

int dpi_yaml_create_float_val(double val) {
    YamlNode n;
    n.type = YamlNode::REAL_VAL;
    n.real_val = val;
    return alloc_handle(n);
}

int dpi_yaml_create_bool_val(int val) {
    YamlNode n;
    n.type = YamlNode::BOOL_VAL;
    n.bool_val = (val != 0);
    return alloc_handle(n);
}

int dpi_yaml_create_null(void) {
    YamlNode n;
    n.type = YamlNode::NULL_VAL;
    return alloc_handle(n);
}

// --- Clone / Free / Valid ---

int dpi_yaml_clone(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return 0;
    return alloc_handle(*n);
}

void dpi_yaml_free(int h) {
    g_handles.erase(h);
}

int dpi_yaml_is_valid(int h) {
    return g_handles.count(h) ? 1 : 0;
}

// --- Structure access ---

int dpi_yaml_get(int h, const char* key) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::MAP_VAL || !key) return 0;
    for (auto& p : n->map_children) {
        if (p.first == key) {
            const YamlNode* child = get_node(p.second);
            if (!child) return 0;
            return alloc_handle(*child);  // deep copy
        }
    }
    return 0;
}

int dpi_yaml_at(int h, int idx) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::SEQ_VAL) return 0;
    if (idx >= 0 && idx < (int)n->seq_children.size()) {
        const YamlNode* child = get_node(n->seq_children[idx]);
        if (!child) return 0;
        return alloc_handle(*child);  // deep copy
    }
    return 0;
}

int dpi_yaml_at_path(int h, const char* path) {
    if (!path) return 0;
    std::string p(path);
    if (p.empty() || p[0] != '/') return 0;

    int current = h;
    size_t pos = 1;
    while (pos < p.size()) {
        size_t next = p.find('/', pos);
        std::string segment = p.substr(pos, next - pos);

        // RFC 6901: ~1 -> / , ~0 -> ~ (order matters: ~1 first)
        size_t tilde;
        while ((tilde = segment.find("~1")) != std::string::npos)
            segment.replace(tilde, 2, "/");
        while ((tilde = segment.find("~0")) != std::string::npos)
            segment.replace(tilde, 2, "~");

        const YamlNode* cur = get_node(current);
        if (!cur) return 0;

        if (cur->type == YamlNode::MAP_VAL) {
            current = dpi_yaml_get(current, segment.c_str());
        } else if (cur->type == YamlNode::SEQ_VAL) {
            int idx = atoi(segment.c_str());
            current = dpi_yaml_at(current, idx);
        } else {
            return 0;
        }

        if (current == 0) return 0;
        if (next == std::string::npos) break;
        pos = next + 1;
    }
    return current;
}

int dpi_yaml_contains(int h, const char* key) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::MAP_VAL || !key) return 0;
    for (auto& p : n->map_children) {
        if (p.first == key) return 1;
    }
    return 0;
}

int dpi_yaml_empty(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return 1;
    if (n->type == YamlNode::MAP_VAL) return n->map_children.empty() ? 1 : 0;
    if (n->type == YamlNode::SEQ_VAL) return n->seq_children.empty() ? 1 : 0;
    return 1;
}

int dpi_yaml_size(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return 0;
    if (n->type == YamlNode::MAP_VAL) return (int)n->map_children.size();
    if (n->type == YamlNode::SEQ_VAL) return (int)n->seq_children.size();
    return 0;
}

const char* dpi_yaml_key_at(int h, int idx) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::MAP_VAL) return "";
    if (idx < 0 || idx >= (int)n->map_children.size()) return "";
    return return_str(n->map_children[idx].first);
}

// --- Modification (returns new handle, original unchanged) ---

int dpi_yaml_set(int h, const char* key, int val_h) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::MAP_VAL || !key) return 0;
    if (!get_node(val_h)) return 0;
    YamlNode new_node = *n;
    bool found = false;
    for (auto& p : new_node.map_children) {
        if (p.first == key) {
            p.second = val_h;
            found = true;
            break;
        }
    }
    if (!found) new_node.map_children.push_back({key, val_h});
    return alloc_handle(new_node);
}

int dpi_yaml_push(int h, int val_h) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::SEQ_VAL) return 0;
    if (!get_node(val_h)) return 0;
    YamlNode new_node = *n;
    new_node.seq_children.push_back(val_h);
    return alloc_handle(new_node);
}

int dpi_yaml_insert_at(int h, int idx, int val_h) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::SEQ_VAL) return 0;
    if (!get_node(val_h)) return 0;
    if (idx < 0 || idx > (int)n->seq_children.size()) return 0;
    YamlNode new_node = *n;
    new_node.seq_children.insert(new_node.seq_children.begin() + idx, val_h);
    return alloc_handle(new_node);
}

int dpi_yaml_remove(int h, const char* key) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::MAP_VAL || !key) return 0;
    YamlNode new_node = *n;
    new_node.map_children.erase(
        std::remove_if(new_node.map_children.begin(), new_node.map_children.end(),
            [key](const std::pair<std::string, int>& p) { return p.first == key; }),
        new_node.map_children.end());
    return alloc_handle(new_node);
}

int dpi_yaml_remove_at(int h, int idx) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::SEQ_VAL) return 0;
    if (idx < 0 || idx >= (int)n->seq_children.size()) return 0;
    YamlNode new_node = *n;
    new_node.seq_children.erase(new_node.seq_children.begin() + idx);
    return alloc_handle(new_node);
}

int dpi_yaml_update(int h, int other_h) {
    const YamlNode* n = get_node(h);
    const YamlNode* o = get_node(other_h);
    if (!n || n->type != YamlNode::MAP_VAL) return 0;
    if (!o || o->type != YamlNode::MAP_VAL) return 0;
    YamlNode new_node = *n;
    for (auto& p : o->map_children) {
        bool found = false;
        for (auto& np : new_node.map_children) {
            if (np.first == p.first) {
                np.second = p.second;
                found = true;
                break;
            }
        }
        if (!found) new_node.map_children.push_back(p);
    }
    return alloc_handle(new_node);
}

// --- Typed set functions ---

int dpi_yaml_set_string(int h, const char* key, const char* value) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::MAP_VAL || !key) return 0;
    YamlNode new_node = *n;
    YamlNode val_node;
    val_node.type = YamlNode::STRING_VAL;
    val_node.str_val = value ? value : "";
    int vh = alloc_handle(val_node);
    bool found = false;
    for (auto& p : new_node.map_children) {
        if (p.first == key) {
            p.second = vh;
            found = true;
            break;
        }
    }
    if (!found) new_node.map_children.push_back({key, vh});
    return alloc_handle(new_node);
}

int dpi_yaml_set_int(int h, const char* key, int value) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::MAP_VAL || !key) return 0;
    YamlNode new_node = *n;
    YamlNode val_node;
    val_node.type = YamlNode::INT_VAL;
    val_node.int_val = value;
    int vh = alloc_handle(val_node);
    bool found = false;
    for (auto& p : new_node.map_children) {
        if (p.first == key) {
            p.second = vh;
            found = true;
            break;
        }
    }
    if (!found) new_node.map_children.push_back({key, vh});
    return alloc_handle(new_node);
}

int dpi_yaml_set_float(int h, const char* key, double value) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::MAP_VAL || !key) return 0;
    YamlNode new_node = *n;
    YamlNode val_node;
    val_node.type = YamlNode::REAL_VAL;
    val_node.real_val = value;
    int vh = alloc_handle(val_node);
    bool found = false;
    for (auto& p : new_node.map_children) {
        if (p.first == key) {
            p.second = vh;
            found = true;
            break;
        }
    }
    if (!found) new_node.map_children.push_back({key, vh});
    return alloc_handle(new_node);
}

int dpi_yaml_set_bool(int h, const char* key, int value) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::MAP_VAL || !key) return 0;
    YamlNode new_node = *n;
    YamlNode val_node;
    val_node.type = YamlNode::BOOL_VAL;
    val_node.bool_val = (value != 0);
    int vh = alloc_handle(val_node);
    bool found = false;
    for (auto& p : new_node.map_children) {
        if (p.first == key) {
            p.second = vh;
            found = true;
            break;
        }
    }
    if (!found) new_node.map_children.push_back({key, vh});
    return alloc_handle(new_node);
}

int dpi_yaml_set_null(int h, const char* key) {
    const YamlNode* n = get_node(h);
    if (!n || n->type != YamlNode::MAP_VAL || !key) return 0;
    YamlNode new_node = *n;
    YamlNode val_node;
    val_node.type = YamlNode::NULL_VAL;
    int vh = alloc_handle(val_node);
    bool found = false;
    for (auto& p : new_node.map_children) {
        if (p.first == key) {
            p.second = vh;
            found = true;
            break;
        }
    }
    if (!found) new_node.map_children.push_back({key, vh});
    return alloc_handle(new_node);
}

// --- Serialization ---

const char* dpi_yaml_dump(int h, int indent) {
    const YamlNode* n = get_node(h);
    if (!n) return "";
    return return_str(emit_yaml_int(h, indent, false));
}

int dpi_yaml_dump_file(int h, const char* fname, int indent) {
    const YamlNode* n = get_node(h);
    if (!n || !fname) return -1;
    std::string yaml = emit_yaml_int(h, indent, false);
    std::ofstream f(fname);
    if (!f.is_open()) return -1;
    f << yaml;
    return f.good() ? 0 : -1;
}

int dpi_yaml_write_file(int h, const char* path, int indent) {
    return dpi_yaml_dump_file(h, path, indent);
}

// --- YAML-specific: multi-document ---

int dpi_yaml_parse_all(const char* input) {
    if (!input) return 0;
    std::string content(input);

    auto parse_as_docs = [](const std::string& s) -> int {
        try {
            c4::csubstr cs = c4::to_csubstr(s);
            ryml_ns::Tree tree = ryml_ns::parse_in_arena(cs);
            ryml_ns::id_type root_id = tree.root_id();
            // If root is a scalar, this is probably a file path, not YAML content
            if (!tree.is_seq(root_id) && !tree.is_map(root_id)) return 0;
            YamlNode root;
            root.type = YamlNode::SEQ_VAL;
            if (tree.has_children(root_id)) {
                ryml_ns::id_type child = tree.first_child(root_id);
                while (child != ryml_ns::NONE) {
                    int dh = ryml_to_handle(tree, child);
                    root.seq_children.push_back(dh);
                    child = tree.next_sibling(child);
                }
            }
            return alloc_handle(root);
        } catch (...) { return 0; }
    };

    // Try as YAML content first
    int result = parse_as_docs(content);
    if (result > 0) return result;

    // Try as file
    std::ifstream f(input);
    if (f.is_open()) {
        content = std::string((std::istreambuf_iterator<char>(f)),
                              std::istreambuf_iterator<char>());
        result = parse_as_docs(content);
        if (result > 0) return result;
    }
    return 0;
}

// --- YAML-specific: comments ---

const char* dpi_yaml_comments(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return "";
    return return_str(n->comment);
}

int dpi_yaml_set_comment(int h, const char* text) {
    const YamlNode* n = get_node(h);
    if (!n) return 0;
    YamlNode new_node = *n;
    new_node.comment = text ? text : "";
    return alloc_handle(new_node);
}

// --- YAML-specific: anchors & aliases ---

const char* dpi_yaml_anchor(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return "";
    return return_str(n->anchor);
}

int dpi_yaml_set_anchor(int h, const char* name) {
    const YamlNode* n = get_node(h);
    if (!n || !name) return 0;
    YamlNode new_node = *n;
    new_node.anchor = name;
    return alloc_handle(new_node);
}

const char* dpi_yaml_alias(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return "";
    return return_str(n->alias_name);
}

// --- YAML-specific: tags ---

const char* dpi_yaml_tag(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return "";
    return return_str(n->tag);
}

int dpi_yaml_set_tag(int h, const char* tag) {
    const YamlNode* n = get_node(h);
    if (!n || !tag) return 0;
    YamlNode new_node = *n;
    new_node.tag = tag;
    return alloc_handle(new_node);
}

// --- YAML-specific: dump variants ---

const char* dpi_yaml_dump_flow(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return "";
    return return_str(emit_yaml_int(h, 0, true));
}

const char* dpi_yaml_dump_with_comments(int h) {
    const YamlNode* n = get_node(h);
    if (!n) return "";
    std::string result = emit_yaml_int(h, 0, false);
    if (!n->comment.empty()) {
        result = "# " + n->comment + "\n" + result;
    }
    return return_str(result);
}

} // extern "C"
