#include "sv_json_dpi.h"
#include "nlohmann/json.hpp"
#include <unordered_map>
#include <string>
#include <fstream>
#include <sstream>

using json = nlohmann::json;

// Error state — referenced by serde::set_error() in serde_common.h
namespace serde {
thread_local std::string g_last_error;
}

// Handle table
static std::unordered_map<int, json> g_handles;
static int g_next_handle = 1;

static int alloc_handle(const json& val) {
    int h = g_next_handle++;
    g_handles[h] = val;
    return h;
}

static json* get_handle(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return nullptr;
    return &it->second;
}

// Persistent string storage for returning const char* safely (bounded)
static std::unordered_map<int, std::string> g_strings;
static int g_next_str_id = 1;
static const size_t MAX_STRINGS = 10000;

static const char* return_str(const std::string& s) {
    int id = g_next_str_id++;
    g_strings[id] = s;
    if (g_strings.size() > MAX_STRINGS) {
        int threshold = g_next_str_id - (int)(MAX_STRINGS / 2);
        for (auto it = g_strings.begin(); it != g_strings.end(); ) {
            if (it->first < threshold)
                it = g_strings.erase(it);
            else
                ++it;
        }
    }
    return g_strings[id].c_str();
}

extern "C" {

// === Error reporting ===

const char* dpi_serde_last_error() {
    return serde::g_last_error.c_str();
}

// === Lifecycle ===

int dpi_json_new_object(void) {
    return alloc_handle(json::object());
}

int dpi_json_new_array(void) {
    return alloc_handle(json::array());
}

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

void dpi_json_destroy(int handle) {
    g_handles.erase(handle);
}

// === Type checking ===

int dpi_json_get_type(int h) {
    json* p = get_handle(h);
    if (!p) return -1;
    if (p->is_null())           return SV_JSON_TYPE_NULL;
    if (p->is_boolean())        return SV_JSON_TYPE_BOOL;
    if (p->is_number_integer()) return SV_JSON_TYPE_INT;
    if (p->is_number_float())   return SV_JSON_TYPE_FLOAT;
    if (p->is_string())         return SV_JSON_TYPE_STRING;
    if (p->is_array())          return SV_JSON_TYPE_ARRAY;
    if (p->is_object())         return SV_JSON_TYPE_OBJECT;
    return -1;
}

// === Value extraction ===

const char* dpi_json_as_string(int h) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return ""; }
    if (!p->is_string()) return "";
    return return_str(p->get<std::string>());
}

int dpi_json_as_int(int h) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (p->is_number_integer()) return p->get<int>();
    if (p->is_number_float())   return static_cast<int>(p->get<double>());
    return 0;
}

double dpi_json_as_real(int h) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0.0; }
    if (p->is_number()) return p->get<double>();
    return 0.0;
}

int dpi_json_as_bool(int h) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_boolean()) return 0;
    return p->get<bool>() ? 1 : 0;
}

// === Structure access ===

int dpi_json_get(int h, const char* key) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_object()) { SET_ERROR("expected object for get('%s'), got type %d", key, dpi_json_get_type(h)); return 0; }
    if (!p->contains(key)) { SET_ERROR("key '%s' not found", key); return 0; }
    return alloc_handle((*p)[key]);
}

int dpi_json_at(int h, int idx) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_array()) { SET_ERROR("expected array for at(%d)", idx); return 0; }
    if (idx < 0 || idx >= (int)p->size()) { SET_ERROR("index %d out of range, size is %d", idx, (int)p->size()); return 0; }
    return alloc_handle((*p)[idx]);
}

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

int dpi_json_contains(int h, const char* key) {
    json* p = get_handle(h);
    if (!p || !p->is_object()) return 0;
    return p->contains(key) ? 1 : 0;
}

int dpi_json_empty(int h) {
    json* p = get_handle(h);
    if (!p) return 1;
    return p->empty() ? 1 : 0;
}

int dpi_json_size(int h) {
    json* p = get_handle(h);
    if (!p) return 0;
    if (p->is_object() || p->is_array()) {
        return (int)p->size();
    }
    return 0;
}

const char* dpi_json_key_at(int h, int idx) {
    json* p = get_handle(h);
    if (!p || !p->is_object()) return "";
    if (idx < 0 || idx >= (int)p->size()) return "";
    auto it = p->begin();
    std::advance(it, idx);
    return return_str(it.key());
}

// === Modification (returns new handle) ===

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

int dpi_json_insert_at(int h, int idx, int val_h) {
    json* p = get_handle(h);
    json* pv = get_handle(val_h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_array()) { SET_ERROR("expected array for insert_at(%d)", idx); return 0; }
    if (!pv) { SET_ERROR("invalid value handle: %d", val_h); return 0; }
    if (idx < 0 || idx > (int)p->size()) { SET_ERROR("insert index %d out of range, size is %d", idx, (int)p->size()); return 0; }
    json new_arr = *p;
    new_arr.insert(new_arr.begin() + idx, *pv);
    return alloc_handle(new_arr);
}

int dpi_json_remove(int h, const char* key) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_object()) { SET_ERROR("expected object for remove('%s')", key); return 0; }
    json new_obj = *p;
    new_obj.erase(key);
    return alloc_handle(new_obj);
}

int dpi_json_remove_at(int h, int idx) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_array()) { SET_ERROR("expected array for remove_at(%d)", idx); return 0; }
    if (idx < 0 || idx >= (int)p->size()) { SET_ERROR("remove index %d out of range, size is %d", idx, (int)p->size()); return 0; }
    json new_arr = *p;
    new_arr.erase(new_arr.begin() + idx);
    return alloc_handle(new_arr);
}

int dpi_json_update(int h, int other_h) {
    json* p = get_handle(h);
    json* po = get_handle(other_h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_object()) { SET_ERROR("expected object for update()"); return 0; }
    if (!po) { SET_ERROR("invalid value handle: %d", other_h); return 0; }
    if (!po->is_object()) { SET_ERROR("expected object for update() value"); return 0; }
    json new_obj = *p;
    new_obj.update(*po);
    return alloc_handle(new_obj);
}

// === Serialization ===

const char* dpi_json_dump(int h, int indent) {
    json* p = get_handle(h);
    if (!p) return "null";
    if (indent < 0) return return_str(p->dump());
    return return_str(p->dump(indent));
}

int dpi_json_dump_file(int h, const char* fname, int indent) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return -1; }
    std::ofstream f(fname);
    if (!f.is_open()) { SET_ERROR("failed to open file for writing: %s", fname); return -1; }
    if (indent < 0) {
        f << p->dump();
    } else {
        f << p->dump(indent);
    }
    return f.good() ? 0 : -1;
}

// === Clone / Free / Valid ===

int dpi_json_clone(int h) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    return alloc_handle(*p);
}

void dpi_json_free(int h) {
    g_handles.erase(h);
}

int dpi_json_is_valid(int h) {
    return g_handles.count(h) ? 1 : 0;
}

// === Create functions for from_* ===

int dpi_json_create_string(const char* val) {
    return alloc_handle(json(val));
}

int dpi_json_create_int_val(int val) {
    return alloc_handle(json(val));
}

int dpi_json_create_float_val(double val) {
    return alloc_handle(json(val));
}

int dpi_json_create_bool_val(int val) {
    return alloc_handle(json(val != 0));
}

int dpi_json_create_null(void) {
    return alloc_handle(json(nullptr));
}

// === Write file (delegates to dump_file for consistent return codes: 0=success, -1=failure) ===

int dpi_json_write_file(int h, const char* path, int indent) {
    return dpi_json_dump_file(h, path, indent);
}

// === Typed set functions ===

int dpi_json_set_string(int h, const char* key, const char* value) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_object()) { SET_ERROR("expected object for set('%s')", key); return 0; }
    json new_obj = *p;
    new_obj[key] = value;
    return alloc_handle(new_obj);
}

int dpi_json_set_int(int h, const char* key, int value) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_object()) { SET_ERROR("expected object for set('%s')", key); return 0; }
    json new_obj = *p;
    new_obj[key] = value;
    return alloc_handle(new_obj);
}

int dpi_json_set_float(int h, const char* key, double value) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_object()) { SET_ERROR("expected object for set('%s')", key); return 0; }
    json new_obj = *p;
    new_obj[key] = value;
    return alloc_handle(new_obj);
}

int dpi_json_set_bool(int h, const char* key, int value) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_object()) { SET_ERROR("expected object for set('%s')", key); return 0; }
    json new_obj = *p;
    new_obj[key] = (value != 0);
    return alloc_handle(new_obj);
}

int dpi_json_set_null(int h, const char* key) {
    json* p = get_handle(h);
    if (!p) { SET_ERROR("invalid handle: %d", h); return 0; }
    if (!p->is_object()) { SET_ERROR("expected object for set('%s')", key); return 0; }
    json new_obj = *p;
    new_obj[key] = nullptr;
    return alloc_handle(new_obj);
}

} // extern "C"
