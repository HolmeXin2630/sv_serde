package sv_yaml_pkg;

  import sv_serde_pkg::sv_serde_type_e;
  import sv_serde_pkg::SERDE_NULL;
  import sv_serde_pkg::SERDE_BOOL;
  import sv_serde_pkg::SERDE_INT;
  import sv_serde_pkg::SERDE_REAL;
  import sv_serde_pkg::SERDE_STRING;
  import sv_serde_pkg::SERDE_ARRAY;
  import sv_serde_pkg::SERDE_OBJECT;

  // Backward-compat type alias and constants
  typedef sv_serde_type_e sv_yaml_type_e;
  localparam SV_YAML_NULL    = SERDE_NULL;
  localparam SV_YAML_BOOLEAN = SERDE_BOOL;
  localparam SV_YAML_INT     = SERDE_INT;
  localparam SV_YAML_REAL    = SERDE_REAL;
  localparam SV_YAML_STRING  = SERDE_STRING;
  localparam SV_YAML_ARRAY   = SERDE_ARRAY;
  localparam SV_YAML_OBJECT  = SERDE_OBJECT;

  // DPI imports — lifecycle
  import "DPI-C" function int    dpi_yaml_parse(input string input_str);
  import "DPI-C" function int    dpi_yaml_new_object();
  import "DPI-C" function int    dpi_yaml_new_array();
  import "DPI-C" function void   dpi_yaml_destroy(input int handle);
  import "DPI-C" function int    dpi_yaml_clone(input int handle);
  import "DPI-C" function void   dpi_yaml_free(input int handle);
  import "DPI-C" function int    dpi_yaml_is_valid(input int handle);

  // DPI imports — type checking
  import "DPI-C" function int    dpi_yaml_get_type(input int h);

  // DPI imports — value extraction
  import "DPI-C" function string dpi_yaml_as_string(input int h);
  import "DPI-C" function int    dpi_yaml_as_int(input int h);
  import "DPI-C" function real   dpi_yaml_as_real(input int h);
  import "DPI-C" function int    dpi_yaml_as_bool(input int h);

  // DPI imports — create functions
  import "DPI-C" function int    dpi_yaml_create_string(input string val);
  import "DPI-C" function int    dpi_yaml_create_int_val(input int val);
  import "DPI-C" function int    dpi_yaml_create_float_val(input real val);
  import "DPI-C" function int    dpi_yaml_create_bool_val(input int val);
  import "DPI-C" function int    dpi_yaml_create_null();

  // DPI imports — structure access
  import "DPI-C" function int    dpi_yaml_get(input int h, input string key);
  import "DPI-C" function int    dpi_yaml_at(input int h, input int idx);
  import "DPI-C" function int    dpi_yaml_at_path(input int h, input string path);
  import "DPI-C" function int    dpi_yaml_contains(input int h, input string key);
  import "DPI-C" function int    dpi_yaml_empty(input int h);
  import "DPI-C" function int    dpi_yaml_size(input int h);
  import "DPI-C" function string dpi_yaml_key_at(input int h, input int idx);

  // DPI imports — modification
  import "DPI-C" function int    dpi_yaml_set(input int h, input string key, input int val_h);
  import "DPI-C" function int    dpi_yaml_push(input int h, input int val_h);
  import "DPI-C" function int    dpi_yaml_insert_at(input int h, input int idx, input int val_h);
  import "DPI-C" function int    dpi_yaml_remove(input int h, input string key);
  import "DPI-C" function int    dpi_yaml_remove_at(input int h, input int idx);
  import "DPI-C" function int    dpi_yaml_update(input int h, input int other_h);

  // DPI imports — typed set functions
  import "DPI-C" function int    dpi_yaml_set_string(input int h, input string key, input string value);
  import "DPI-C" function int    dpi_yaml_set_int(input int h, input string key, input int value);
  import "DPI-C" function int    dpi_yaml_set_float(input int h, input string key, input real value);
  import "DPI-C" function int    dpi_yaml_set_bool(input int h, input string key, input int value);
  import "DPI-C" function int    dpi_yaml_set_null(input int h, input string key);

  // DPI imports — serialization
  import "DPI-C" function string dpi_yaml_dump(input int h, input int indent);
  import "DPI-C" function int    dpi_yaml_dump_file(input int h, input string fname, input int indent);
  import "DPI-C" function int    dpi_yaml_write_file(input int h, input string path, input int indent);

  // DPI imports — YAML-specific
  import "DPI-C" function int    dpi_yaml_parse_all(input string input_str);
  import "DPI-C" function string dpi_yaml_comments(input int h);
  import "DPI-C" function int    dpi_yaml_set_comment(input int h, input string text);
  import "DPI-C" function string dpi_yaml_anchor(input int h);
  import "DPI-C" function int    dpi_yaml_set_anchor(input int h, input string name);
  import "DPI-C" function string dpi_yaml_alias(input int h);
  import "DPI-C" function string dpi_yaml_tag(input int h);
  import "DPI-C" function int    dpi_yaml_set_tag(input int h, input string tag);
  import "DPI-C" function string dpi_yaml_dump_flow(input int h);
  import "DPI-C" function string dpi_yaml_dump_with_comments(input int h);

  // DPI imports — error reporting
  import "DPI-C" function string dpi_serde_last_error();

  `include "sv_serde_base.svh"

  class sv_yaml extends sv_serde_base;

    static protected sv_yaml s_tmp;

    function new();
      super.new();
    endfunction

    function void init(int handle, sv_serde_type_e serde_type);
      super.init(handle, serde_type);
    endfunction

    // --- DPI dispatch virtual overrides (one-liner delegates) ---
    function int   dpi_parse(string s);           return dpi_yaml_parse(s);           endfunction
    function int   dpi_new_object();              return dpi_yaml_new_object();       endfunction
    function int   dpi_new_array();               return dpi_yaml_new_array();        endfunction
    function int   dpi_create_string(string v);   return dpi_yaml_create_string(v);   endfunction
    function int   dpi_create_int_val(int v);     return dpi_yaml_create_int_val(v);  endfunction
    function int   dpi_create_float_val(real v);  return dpi_yaml_create_float_val(v);endfunction
    function int   dpi_create_bool_val(int v);    return dpi_yaml_create_bool_val(v); endfunction
    function int   dpi_create_null();             return dpi_yaml_create_null();      endfunction
    function int   dpi_get(int h, string k);      return dpi_yaml_get(h, k);          endfunction
    function int   dpi_at(int h, int i);          return dpi_yaml_at(h, i);           endfunction
    function int   dpi_at_path(int h, string p);  return dpi_yaml_at_path(h, p);      endfunction
    function int   dpi_contains(int h, string k); return dpi_yaml_contains(h, k);     endfunction
    function int   dpi_empty(int h);              return dpi_yaml_empty(h);           endfunction
    function int   dpi_size(int h);               return dpi_yaml_size(h);            endfunction
    function string dpi_key_at(int h, int i);     return dpi_yaml_key_at(h, i);       endfunction
    function int    dpi_set(int h, string k, int v);       return dpi_yaml_set(h, k, v);       endfunction
    function int    dpi_push(int h, int v);               return dpi_yaml_push(h, v);          endfunction
    function int    dpi_insert_at(int h, int i, int v);   return dpi_yaml_insert_at(h, i, v);  endfunction
    function int    dpi_remove(int h, string k);          return dpi_yaml_remove(h, k);        endfunction
    function int    dpi_remove_at(int h, int i);          return dpi_yaml_remove_at(h, i);     endfunction
    function int    dpi_update(int h, int o);             return dpi_yaml_update(h, o);        endfunction
    function int    dpi_set_string(int h, string k, string v); return dpi_yaml_set_string(h, k, v); endfunction
    function int    dpi_set_int(int h, string k, int v);      return dpi_yaml_set_int(h, k, v);      endfunction
    function int    dpi_set_float(int h, string k, real v);   return dpi_yaml_set_float(h, k, v);    endfunction
    function int    dpi_set_bool(int h, string k, int v);     return dpi_yaml_set_bool(h, k, v);     endfunction
    function int    dpi_set_null(int h, string k);            return dpi_yaml_set_null(h, k);        endfunction
    function string dpi_as_string(int h);     return dpi_yaml_as_string(h);     endfunction
    function int    dpi_as_int(int h);         return dpi_yaml_as_int(h);       endfunction
    function real   dpi_as_real(int h);        return dpi_yaml_as_real(h);      endfunction
    function int    dpi_as_bool(int h);        return dpi_yaml_as_bool(h);      endfunction
    function string dpi_dump(int h, int i);    return dpi_yaml_dump(h, i);      endfunction
    function int    dpi_dump_file(int h, string f, int i); return dpi_yaml_dump_file(h, f, i); endfunction
    function int    dpi_clone(int h);          return dpi_yaml_clone(h);        endfunction
    function void   dpi_destroy(int h);        dpi_yaml_free(h);               endfunction
    function int    dpi_is_valid(int h);       return dpi_yaml_is_valid(h);    endfunction
    function string dpi_last_error();          return dpi_serde_last_error();  endfunction
    function int    dpi_get_type(int h);        return dpi_yaml_get_type(h);   endfunction

    // --- Factory method ---
    function sv_serde_base make_child(int h, sv_serde_type_e t);
      sv_yaml child;
      child = new();
      child.init(h, t);
      child.m_strict_mode = this.m_strict_mode;
      return child;
    endfunction

    // --- Public accessors (shadow base _xxx methods with correct return type) ---
    function sv_yaml get(string key);
      sv_serde_base v = super._get(key);
      if (v == null) return null;
      $cast(get, v);
    endfunction

    function sv_yaml at(int idx);
      sv_serde_base v = super._at(idx);
      if (v == null) return null;
      $cast(at, v);
    endfunction

    function sv_yaml at_path(string path);
      sv_serde_base v = super._at_path(path);
      if (v == null) return null;
      $cast(at_path, v);
    endfunction

    function sv_yaml set(string key, sv_yaml value);
      sv_serde_base v = super._set(key, value);
      if (v == null) return null;
      $cast(set, v);
    endfunction

    function sv_yaml push(sv_yaml value);
      sv_serde_base v = super._push(value);
      if (v == null) return null;
      $cast(push, v);
    endfunction

    function sv_yaml insert_at(int idx, sv_yaml value);
      sv_serde_base v = super._insert_at(idx, value);
      if (v == null) return null;
      $cast(insert_at, v);
    endfunction

    function sv_yaml remove(string key);
      sv_serde_base v = super._remove(key);
      if (v == null) return null;
      $cast(remove, v);
    endfunction

    function sv_yaml remove_at(int idx);
      sv_serde_base v = super._remove_at(idx);
      if (v == null) return null;
      $cast(remove_at, v);
    endfunction

    function sv_yaml update(sv_yaml other);
      sv_serde_base v = super._update(other);
      if (v == null) return null;
      $cast(update, v);
    endfunction

    function sv_yaml clone();
      sv_serde_base v = super._clone();
      if (v == null) return null;
      $cast(clone, v);
    endfunction

    // --- Static factory methods ---
    static function sv_yaml parse(string input_str);
      int h = dpi_yaml_parse(input_str);
      if (h == 0) return null;
      s_tmp = new();
      s_tmp.init(h, sv_serde_type_e'(dpi_yaml_get_type(h)));
      return s_tmp;
    endfunction

    static function sv_yaml new_object();
      s_tmp = new();
      s_tmp.init(dpi_yaml_new_object(), SERDE_OBJECT);
      return s_tmp;
    endfunction

    static function sv_yaml new_array();
      s_tmp = new();
      s_tmp.init(dpi_yaml_new_array(), SERDE_ARRAY);
      return s_tmp;
    endfunction

    static function sv_yaml from_string(string val);
      s_tmp = new();
      s_tmp.init(dpi_yaml_create_string(val), SERDE_STRING);
      return s_tmp;
    endfunction

    static function sv_yaml from_int(int val);
      s_tmp = new();
      s_tmp.init(dpi_yaml_create_int_val(val), SERDE_INT);
      return s_tmp;
    endfunction

    static function sv_yaml from_real(real val);
      s_tmp = new();
      s_tmp.init(dpi_yaml_create_float_val(val), SERDE_REAL);
      return s_tmp;
    endfunction

    static function sv_yaml from_bool(bit val);
      s_tmp = new();
      s_tmp.init(dpi_yaml_create_bool_val(val ? 1 : 0), SERDE_BOOL);
      return s_tmp;
    endfunction

    static function sv_yaml make_null();
      s_tmp = new();
      s_tmp.init(dpi_yaml_create_null(), SERDE_NULL);
      return s_tmp;
    endfunction

    // --- YAML-specific methods ---
    static function sv_yaml yaml_parse_all(string input_str);
      int h = dpi_yaml_parse_all(input_str);
      if (h == 0) return null;
      sv_yaml result;
      result = new();
      s_tmp.init(h, sv_serde_type_e'(dpi_yaml_get_type(h)));
      return s_tmp;
    endfunction

    function string yaml_comments();
      return dpi_yaml_comments(m_handle);
    endfunction

    function sv_yaml yaml_set_comment(string text);
      int h = dpi_yaml_set_comment(m_handle, text);
      if (h == 0) return null;
      sv_yaml result;
      result = new();
      s_tmp.init(h, sv_serde_type_e'(dpi_yaml_get_type(h)));
      return s_tmp;
    endfunction

    function string yaml_anchor();
      return dpi_yaml_anchor(m_handle);
    endfunction

    function sv_yaml yaml_set_anchor(string name);
      int h = dpi_yaml_set_anchor(m_handle, name);
      if (h == 0) return null;
      sv_yaml result;
      result = new();
      s_tmp.init(h, sv_serde_type_e'(dpi_yaml_get_type(h)));
      return s_tmp;
    endfunction

    function string yaml_alias();
      return dpi_yaml_alias(m_handle);
    endfunction

    function string yaml_tag();
      return dpi_yaml_tag(m_handle);
    endfunction

    function sv_yaml yaml_set_tag(string tag);
      int h = dpi_yaml_set_tag(m_handle, tag);
      if (h == 0) return null;
      sv_yaml result;
      result = new();
      s_tmp.init(h, sv_serde_type_e'(dpi_yaml_get_type(h)));
      return s_tmp;
    endfunction

    function string yaml_dump_flow();
      return dpi_yaml_dump_flow(m_handle);
    endfunction

    function string yaml_dump_with_comments();
      return dpi_yaml_dump_with_comments(m_handle);
    endfunction

  endclass

endpackage
