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

int dpi_json_is_null(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return 0;
    return it->second.is_null() ? 1 : 0;
}

int dpi_json_is_boolean(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return 0;
    return it->second.is_boolean() ? 1 : 0;
}

int dpi_json_is_int(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return 0;
    return it->second.is_number_integer() ? 1 : 0;
}

int dpi_json_is_real(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return 0;
    return it->second.is_number_float() ? 1 : 0;
}

int dpi_json_is_string(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return 0;
    return it->second.is_string() ? 1 : 0;
}

int dpi_json_is_array(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return 0;
    return it->second.is_array() ? 1 : 0;
}

int dpi_json_is_object(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return 0;
    return it->second.is_object() ? 1 : 0;
}

int dpi_json_get_type(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return -1;
    const json& val = it->second;
    if (val.is_null()) return 0;
    if (val.is_boolean()) return 1;
    if (val.is_number_integer()) return 2;
    if (val.is_number_float()) return 3;
    if (val.is_string()) return 4;
    if (val.is_array()) return 5;
    if (val.is_object()) return 6;
    return -1;
}

// === Value extraction ===

const char* dpi_json_as_string(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end() || !it->second.is_string()) return "";
    return it->second.get_ref<const std::string&>().c_str();
}

int dpi_json_as_int(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end() || !it->second.is_number_integer()) return 0;
    return it->second.get<int>();
}

double dpi_json_as_real(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end() || !it->second.is_number_float()) return 0.0;
    return it->second.get<double>();
}

int dpi_json_as_bool(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end() || !it->second.is_boolean()) return 0;
    return it->second.get<bool>() ? 1 : 0;
}

// === Structure access ===

int dpi_json_get(int h, const char* key) {
    auto it = g_handles.find(h);
    if (it == g_handles.end() || !it->second.is_object()) return 0;
    if (it->second.contains(key)) {
        return alloc_handle(it->second[key]);
    }
    return 0;
}

int dpi_json_at(int h, int idx) {
    auto it = g_handles.find(h);
    if (it == g_handles.end() || !it->second.is_array()) return 0;
    if (idx >= 0 && idx < (int)it->second.size()) {
        return alloc_handle(it->second[idx]);
    }
    return 0;
}

int dpi_json_at_path(int h, const char* path) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return 0;
    try {
        json result = it->second.at(json::json_pointer(path));
        return alloc_handle(result);
    } catch (...) {
        return 0;
    }
}

int dpi_json_contains(int h, const char* key) {
    auto it = g_handles.find(h);
    if (it == g_handles.end() || !it->second.is_object()) return 0;
    return it->second.contains(key) ? 1 : 0;
}

int dpi_json_empty(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return 1;
    return it->second.empty() ? 1 : 0;
}

int dpi_json_size(int h) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return 0;
    if (it->second.is_object() || it->second.is_array()) {
        return (int)it->second.size();
    }
    return 0;
}

const char* dpi_json_key_at(int h, int idx) {
    auto it = g_handles.find(h);
    if (it == g_handles.end() || !it->second.is_object()) return "";
    if (idx < 0 || idx >= (int)it->second.size()) return "";
    auto it2 = it->second.begin();
    std::advance(it2, idx);
    static thread_local std::string buf;
    buf = it2.key();
    return buf.c_str();
}

// === Modification (returns new handle) ===

int dpi_json_set(int h, const char* key, int val_h) {
    auto it = g_handles.find(h);
    auto itv = g_handles.find(val_h);
    if (it == g_handles.end() || !it->second.is_object()) return 0;
    if (itv == g_handles.end()) return 0;
    json new_obj = it->second;
    new_obj[key] = itv->second;
    return alloc_handle(new_obj);
}

int dpi_json_push(int h, int val_h) {
    auto it = g_handles.find(h);
    auto itv = g_handles.find(val_h);
    if (it == g_handles.end() || !it->second.is_array()) return 0;
    if (itv == g_handles.end()) return 0;
    json new_arr = it->second;
    new_arr.push_back(itv->second);
    return alloc_handle(new_arr);
}

int dpi_json_insert_at(int h, int idx, int val_h) {
    auto it = g_handles.find(h);
    auto itv = g_handles.find(val_h);
    if (it == g_handles.end() || !it->second.is_array()) return 0;
    if (itv == g_handles.end()) return 0;
    if (idx < 0 || idx > (int)it->second.size()) return 0;
    json new_arr = it->second;
    new_arr.insert(new_arr.begin() + idx, itv->second);
    return alloc_handle(new_arr);
}

int dpi_json_remove(int h, const char* key) {
    auto it = g_handles.find(h);
    if (it == g_handles.end() || !it->second.is_object()) return 0;
    json new_obj = it->second;
    new_obj.erase(key);
    return alloc_handle(new_obj);
}

int dpi_json_remove_at(int h, int idx) {
    auto it = g_handles.find(h);
    if (it == g_handles.end() || !it->second.is_array()) return 0;
    if (idx < 0 || idx >= (int)it->second.size()) return 0;
    json new_arr = it->second;
    new_arr.erase(new_arr.begin() + idx);
    return alloc_handle(new_arr);
}

int dpi_json_update(int h, int other_h) {
    auto it = g_handles.find(h);
    auto ito = g_handles.find(other_h);
    if (it == g_handles.end() || !it->second.is_object()) return 0;
    if (ito == g_handles.end() || !ito->second.is_object()) return 0;
    json new_obj = it->second;
    new_obj.update(ito->second);
    return alloc_handle(new_obj);
}

// === Serialization ===

const char* dpi_json_dump(int h, int indent) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return "";
    static thread_local std::string buf;
    if (indent < 0) {
        buf = it->second.dump();
    } else {
        buf = it->second.dump(indent);
    }
    return buf.c_str();
}

int dpi_json_dump_file(int h, const char* fname, int indent) {
    auto it = g_handles.find(h);
    if (it == g_handles.end()) return -1;
    std::ofstream f(fname);
    if (!f.is_open()) return -1;
    if (indent < 0) {
        f << it->second.dump();
    } else {
        f << it->second.dump(indent);
    }
    return f.good() ? 0 : -1;
}

} // extern "C"
