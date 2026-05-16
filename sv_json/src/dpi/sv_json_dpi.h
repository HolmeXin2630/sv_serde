#ifndef SV_JSON_DPI_H
#define SV_JSON_DPI_H

#include "serde_common.h"

#ifdef __cplusplus
extern "C" {
#endif

// Object lifecycle
int dpi_json_new_object(void);
int dpi_json_new_array(void);
int dpi_json_parse(const char* input);
void dpi_json_destroy(int handle);
int dpi_json_clone(int h);
void dpi_json_free(int h);
int dpi_json_is_valid(int h);

// Type checking
int dpi_json_get_type(int h);

// Value extraction
const char* dpi_json_as_string(int h);
int dpi_json_as_int(int h);
double dpi_json_as_real(int h);
int dpi_json_as_bool(int h);

// Create functions (for from_* factory methods)
int dpi_json_create_string(const char* val);
int dpi_json_create_int_val(int val);
int dpi_json_create_float_val(double val);
int dpi_json_create_bool_val(int val);
int dpi_json_create_null(void);

// Structure access
int dpi_json_get(int h, const char* key);
int dpi_json_at(int h, int idx);
int dpi_json_at_path(int h, const char* path);
int dpi_json_contains(int h, const char* key);
int dpi_json_empty(int h);
int dpi_json_size(int h);
const char* dpi_json_key_at(int h, int idx);

// Modification (returns new handle, original unchanged)
int dpi_json_set(int h, const char* key, int val_h);
int dpi_json_push(int h, int val_h);
int dpi_json_insert_at(int h, int idx, int val_h);
int dpi_json_remove(int h, const char* key);
int dpi_json_remove_at(int h, int idx);
int dpi_json_update(int h, int other_h);

// Typed set functions
int dpi_json_set_string(int h, const char* key, const char* value);
int dpi_json_set_int(int h, const char* key, int value);
int dpi_json_set_float(int h, const char* key, double value);
int dpi_json_set_bool(int h, const char* key, int value);
int dpi_json_set_null(int h, const char* key);

// Serialization
const char* dpi_json_dump(int h, int indent);
int dpi_json_dump_file(int h, const char* fname, int indent);
int dpi_json_write_file(int h, const char* path, int indent);

#ifdef __cplusplus
}
#endif

#endif // SV_JSON_DPI_H
