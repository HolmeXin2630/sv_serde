#include "sv_json_dpi.h"
#include "nlohmann/json.hpp"
#include <unordered_map>
#include <string>
#include <fstream>
#include <sstream>

using json = nlohmann::json;

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

// Persistent string storage for returning const char* safely
static std::unordered_map<int, std::string> g_strings;
static int g_next_str_id = 1;

static const char* return_str(const std::string& s) {
    int id = g_next_str_id++;
    g_strings[id] = s;
    return g_strings[id].c_str();
}

extern "C" {

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
    } catch (...) {
        std::ifstream f(input);
        if (f.is_open()) {
            try {
                json j;
                f >> j;
                return alloc_handle(j);
            } catch (...) {
                return 0;
            }
        }
        return 0;
    }
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
    if (!p || !p->is_string()) return "";
    return return_str(p->get<std::string>());
}

int dpi_json_as_int(int h) {
    json* p = get_handle(h);
    if (!p) return 0;
    if (p->is_number_integer()) return p->get<int>();
    if (p->is_number_float())   return static_cast<int>(p->get<double>());
    return 0;
}

double dpi_json_as_real(int h) {
    json* p = get_handle(h);
    if (!p) return 0.0;
    if (p->is_number()) return p->get<double>();
    return 0.0;
}

int dpi_json_as_bool(int h) {
    json* p = get_handle(h);
    if (!p || !p->is_boolean()) return 0;
    return p->get<bool>() ? 1 : 0;
}

// === Structure access ===

int dpi_json_get(int h, const char* key) {
    json* p = get_handle(h);
    if (!p || !p->is_object()) return 0;
    if (p->contains(key)) {
        return alloc_handle((*p)[key]);
    }
    return 0;
}

int dpi_json_at(int h, int idx) {
    json* p = get_handle(h);
    if (!p || !p->is_array()) return 0;
    if (idx >= 0 && idx < (int)p->size()) {
        return alloc_handle((*p)[idx]);
    }
    return 0;
}

int dpi_json_at_path(int h, const char* path) {
    json* p = get_handle(h);
    if (!p) return 0;
    try {
        json result = p->at(json::json_pointer(path));
        return alloc_handle(result);
    } catch (...) {
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
    if (!p || !p->is_object() || !pv) return 0;
    json new_obj = *p;
    new_obj[key] = *pv;
    return alloc_handle(new_obj);
}

int dpi_json_push(int h, int val_h) {
    json* p = get_handle(h);
    json* pv = get_handle(val_h);
    if (!p || !p->is_array() || !pv) return 0;
    json new_arr = *p;
    new_arr.push_back(*pv);
    return alloc_handle(new_arr);
}

int dpi_json_insert_at(int h, int idx, int val_h) {
    json* p = get_handle(h);
    json* pv = get_handle(val_h);
    if (!p || !p->is_array() || !pv) return 0;
    if (idx < 0 || idx > (int)p->size()) return 0;
    json new_arr = *p;
    new_arr.insert(new_arr.begin() + idx, *pv);
    return alloc_handle(new_arr);
}

int dpi_json_remove(int h, const char* key) {
    json* p = get_handle(h);
    if (!p || !p->is_object()) return 0;
    json new_obj = *p;
    new_obj.erase(key);
    return alloc_handle(new_obj);
}

int dpi_json_remove_at(int h, int idx) {
    json* p = get_handle(h);
    if (!p || !p->is_array()) return 0;
    if (idx < 0 || idx >= (int)p->size()) return 0;
    json new_arr = *p;
    new_arr.erase(new_arr.begin() + idx);
    return alloc_handle(new_arr);
}

int dpi_json_update(int h, int other_h) {
    json* p = get_handle(h);
    json* po = get_handle(other_h);
    if (!p || !p->is_object() || !po || !po->is_object()) return 0;
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
    if (!p) return -1;
    std::ofstream f(fname);
    if (!f.is_open()) return -1;
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
    if (!p) return 0;
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

// === Write file ===

int dpi_json_write_file(int h, const char* path, int indent) {
    json* p = get_handle(h);
    if (!p) return 0;
    try {
        std::ofstream f(path);
        if (!f.is_open()) return 0;
        f << (indent > 0 ? p->dump(indent) : p->dump());
        return 1;
    } catch (...) { return 0; }
}

// === Typed set functions ===

int dpi_json_set_string(int h, const char* key, const char* value) {
    json* p = get_handle(h);
    if (!p || !p->is_object()) return 0;
    json new_obj = *p;
    new_obj[key] = value;
    return alloc_handle(new_obj);
}

int dpi_json_set_int(int h, const char* key, int value) {
    json* p = get_handle(h);
    if (!p || !p->is_object()) return 0;
    json new_obj = *p;
    new_obj[key] = value;
    return alloc_handle(new_obj);
}

int dpi_json_set_float(int h, const char* key, double value) {
    json* p = get_handle(h);
    if (!p || !p->is_object()) return 0;
    json new_obj = *p;
    new_obj[key] = value;
    return alloc_handle(new_obj);
}

int dpi_json_set_bool(int h, const char* key, int value) {
    json* p = get_handle(h);
    if (!p || !p->is_object()) return 0;
    json new_obj = *p;
    new_obj[key] = (value != 0);
    return alloc_handle(new_obj);
}

int dpi_json_set_null(int h, const char* key) {
    json* p = get_handle(h);
    if (!p || !p->is_object()) return 0;
    json new_obj = *p;
    new_obj[key] = nullptr;
    return alloc_handle(new_obj);
}

} // extern "C"
