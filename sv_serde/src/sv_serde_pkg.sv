// sv_serde_pkg: Unified package for sv_json + sv_yaml
//
// Usage:
//   import sv_serde_pkg::*;      // both JSON and YAML
//   import sv_json_pkg::*;       // JSON only
//   import sv_yaml_pkg::*;       // YAML only
//
package sv_serde_pkg;
  import sv_json_pkg::*;
  import sv_yaml_pkg::*;
endpackage
