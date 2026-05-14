#ifndef SV_JSON_DPI_H
#define SV_JSON_DPI_H

#ifdef __cplusplus
extern "C" {
#endif

// Object lifecycle
int dpi_json_new_object(void);
int dpi_json_new_array(void);
int dpi_json_parse(const char* input);
void dpi_json_destroy(int handle);

// Type checking
int dpi_json_is_null(int h);
int dpi_json_is_boolean(int h);
int dpi_json_is_int(int h);
int dpi_json_is_real(int h);
int dpi_json_is_string(int h);
int dpi_json_is_array(int h);
int dpi_json_is_object(int h);
int dpi_json_get_type(int h);

// Value extraction
const char* dpi_json_as_string(int h);
int dpi_json_as_int(int h);
double dpi_json_as_real(int h);
int dpi_json_as_bool(int h);

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

// Serialization
const char* dpi_json_dump(int h, int indent);
int dpi_json_dump_file(int h, const char* fname, int indent);

#ifdef __cplusplus
}
#endif

#endif // SV_JSON_DPI_H
