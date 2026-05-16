#ifndef SERDE_COMMON_H
#define SERDE_COMMON_H

// Shared type codes for JSON and YAML backends.
// Must match sv_json_type_e / sv_yaml_type_e enums in SV packages.
#define SERDE_TYPE_NULL    0
#define SERDE_TYPE_BOOL    1
#define SERDE_TYPE_INT     2
#define SERDE_TYPE_FLOAT   3
#define SERDE_TYPE_STRING  4
#define SERDE_TYPE_ARRAY   5
#define SERDE_TYPE_OBJECT  6

// Backward-compatible aliases
#define SV_JSON_TYPE_NULL    SERDE_TYPE_NULL
#define SV_JSON_TYPE_BOOL    SERDE_TYPE_BOOL
#define SV_JSON_TYPE_INT     SERDE_TYPE_INT
#define SV_JSON_TYPE_FLOAT   SERDE_TYPE_FLOAT
#define SV_JSON_TYPE_STRING  SERDE_TYPE_STRING
#define SV_JSON_TYPE_ARRAY   SERDE_TYPE_ARRAY
#define SV_JSON_TYPE_OBJECT  SERDE_TYPE_OBJECT

#define SV_YAML_TYPE_NULL    SERDE_TYPE_NULL
#define SV_YAML_TYPE_BOOL    SERDE_TYPE_BOOL
#define SV_YAML_TYPE_INT     SERDE_TYPE_INT
#define SV_YAML_TYPE_FLOAT   SERDE_TYPE_FLOAT
#define SV_YAML_TYPE_STRING  SERDE_TYPE_STRING
#define SV_YAML_TYPE_ARRAY   SERDE_TYPE_ARRAY
#define SV_YAML_TYPE_OBJECT  SERDE_TYPE_OBJECT

// Error reporting — thread-safe last-error buffer
#ifdef __cplusplus
extern "C" {
#endif
const char* dpi_serde_last_error(void);
#ifdef __cplusplus
}
#endif

// Helper macro and namespace for DPI backends to set error messages
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

#endif // SERDE_COMMON_H
