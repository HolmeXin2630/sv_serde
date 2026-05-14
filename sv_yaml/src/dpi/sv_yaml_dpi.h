#ifndef SV_YAML_DPI_H
#define SV_YAML_DPI_H

#ifdef __cplusplus
extern "C" {
#endif

// Object lifecycle
int dpi_yaml_new_object(void);
int dpi_yaml_new_array(void);
int dpi_yaml_parse(const char* input);
void dpi_yaml_destroy(int handle);

// Type checking
int dpi_yaml_is_null(int h);
int dpi_yaml_is_boolean(int h);
int dpi_yaml_is_int(int h);
int dpi_yaml_is_real(int h);
int dpi_yaml_is_string(int h);
int dpi_yaml_is_array(int h);
int dpi_yaml_is_object(int h);
int dpi_yaml_get_type(int h);

// Value extraction
const char* dpi_yaml_as_string(int h);
int dpi_yaml_as_int(int h);
double dpi_yaml_as_real(int h);
int dpi_yaml_as_bool(int h);

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

// Serialization
const char* dpi_yaml_dump(int h, int indent);
int dpi_yaml_dump_file(int h, const char* fname, int indent);

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
