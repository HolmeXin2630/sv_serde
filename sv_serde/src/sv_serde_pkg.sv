// sv_serde_pkg: Unified package for sv_json + sv_yaml
//
// Usage:
//   import sv_serde_pkg::*;      // both JSON and YAML
//   import sv_json_pkg::*;       // JSON only
//   import sv_yaml_pkg::*;       // YAML only
//
package sv_serde_pkg;

  // Unified type enum — single source of truth for all formats
  // Must match SERDE_TYPE_* macros in sv_serde/src/dpi/serde_common.h
  typedef enum int {
    SERDE_NULL   = 0,
    SERDE_BOOL   = 1,
    SERDE_INT    = 2,
    SERDE_REAL   = 3,
    SERDE_STRING = 4,
    SERDE_ARRAY  = 5,
    SERDE_OBJECT = 6
  } sv_serde_type_e;

  // Backward-compatible type aliases
  typedef sv_serde_type_e sv_json_type_e;
  typedef sv_serde_type_e sv_yaml_type_e;

  // Backward-compatible constants
  localparam SV_JSON_NULL    = SERDE_NULL;
  localparam SV_JSON_BOOLEAN = SERDE_BOOL;
  localparam SV_JSON_INT     = SERDE_INT;
  localparam SV_JSON_REAL    = SERDE_REAL;
  localparam SV_JSON_STRING  = SERDE_STRING;
  localparam SV_JSON_ARRAY   = SERDE_ARRAY;
  localparam SV_JSON_OBJECT  = SERDE_OBJECT;

  localparam SV_YAML_NULL    = SERDE_NULL;
  localparam SV_YAML_BOOLEAN = SERDE_BOOL;
  localparam SV_YAML_INT     = SERDE_INT;
  localparam SV_YAML_REAL    = SERDE_REAL;
  localparam SV_YAML_STRING  = SERDE_STRING;
  localparam SV_YAML_ARRAY   = SERDE_ARRAY;
  localparam SV_YAML_OBJECT  = SERDE_OBJECT;


endpackage
