#ifndef SV_YAML_DPI_H
#define SV_YAML_DPI_H

#include "serde_common.h"

#ifdef __cplusplus
extern "C" {
#endif

// Object lifecycle
int dpi_yaml_new_object(void);
int dpi_yaml_new_array(void);
int dpi_yaml_parse(const char* input);
void dpi_yaml_destroy(int handle);
int dpi_yaml_clone(int h);
void dpi_yaml_free(int h);
int dpi_yaml_is_valid(int h);

// Type checking
int dpi_yaml_get_type(int h);

// Value extraction
const char* dpi_yaml_as_string(int h);
int dpi_yaml_as_int(int h);
double dpi_yaml_as_real(int h);
int dpi_yaml_as_bool(int h);

// Create functions (for from_* factory methods)
int dpi_yaml_create_string(const char* val);
int dpi_yaml_create_int_val(int val);
int dpi_yaml_create_float_val(double val);
int dpi_yaml_create_bool_val(int val);
int dpi_yaml_create_null(void);

// Structure access
int dpi_yaml_get(int h, const char* key);
int dpi_yaml_at(int h, int idx);
int dpi_yaml_at_path(int h, const char* path);
int dpi_yaml_contains(int h, const char* key);
int dpi_yaml_empty(int h);
int dpi_yaml_size(int h);
const char* dpi_yaml_key_at(int h, int idx);

// Modification (returns new handle, original unchanged)
int dpi_yaml_set(int h, const char* key, int val_h);
int dpi_yaml_push(int h, int val_h);
int dpi_yaml_insert_at(int h, int idx, int val_h);
int dpi_yaml_remove(int h, const char* key);
int dpi_yaml_remove_at(int h, int idx);
int dpi_yaml_update(int h, int other_h);

// Typed set functions
int dpi_yaml_set_string(int h, const char* key, const char* value);
int dpi_yaml_set_int(int h, const char* key, int value);
int dpi_yaml_set_float(int h, const char* key, double value);
int dpi_yaml_set_bool(int h, const char* key, int value);
int dpi_yaml_set_null(int h, const char* key);

// Serialization
const char* dpi_yaml_dump(int h, int indent);
int dpi_yaml_dump_file(int h, const char* fname, int indent);
int dpi_yaml_write_file(int h, const char* path, int indent);

// YAML-specific: multi-document
int dpi_yaml_parse_all(const char* input);

// YAML-specific: comments
const char* dpi_yaml_comments(int h);
int dpi_yaml_set_comment(int h, const char* text);

// YAML-specific: anchors & aliases
const char* dpi_yaml_anchor(int h);
int dpi_yaml_set_anchor(int h, const char* name);
const char* dpi_yaml_alias(int h);

// YAML-specific: tags
const char* dpi_yaml_tag(int h);
int dpi_yaml_set_tag(int h, const char* tag);

// YAML-specific: dump variants
const char* dpi_yaml_dump_flow(int h);
const char* dpi_yaml_dump_with_comments(int h);

#ifdef __cplusplus
}
#endif

#endif // SV_YAML_DPI_H
