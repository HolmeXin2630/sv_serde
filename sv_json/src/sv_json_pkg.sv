package sv_json_pkg;

  import sv_serde_pkg::sv_serde_type_e;
  import sv_serde_pkg::SERDE_NULL;
  import sv_serde_pkg::SERDE_BOOL;
  import sv_serde_pkg::SERDE_INT;
  import sv_serde_pkg::SERDE_REAL;
  import sv_serde_pkg::SERDE_STRING;
  import sv_serde_pkg::SERDE_ARRAY;
  import sv_serde_pkg::SERDE_OBJECT;

  // Backward-compat type alias and constants
  typedef sv_serde_type_e sv_json_type_e;
  localparam SV_JSON_NULL    = SERDE_NULL;
  localparam SV_JSON_BOOLEAN = SERDE_BOOL;
  localparam SV_JSON_INT     = SERDE_INT;
  localparam SV_JSON_REAL    = SERDE_REAL;
  localparam SV_JSON_STRING  = SERDE_STRING;
  localparam SV_JSON_ARRAY   = SERDE_ARRAY;
  localparam SV_JSON_OBJECT  = SERDE_OBJECT;

  // DPI imports — lifecycle
  import "DPI-C" function int    dpi_json_parse(input string input_str);
  import "DPI-C" function int    dpi_json_new_object();
  import "DPI-C" function int    dpi_json_new_array();
  import "DPI-C" function void   dpi_json_destroy(input int handle);
  import "DPI-C" function int    dpi_json_clone(input int handle);
  import "DPI-C" function void   dpi_json_free(input int handle);
  import "DPI-C" function int    dpi_json_is_valid(input int handle);

  // DPI imports — type checking
  import "DPI-C" function int    dpi_json_get_type(input int h);

  // DPI imports — value extraction
  import "DPI-C" function string dpi_json_as_string(input int h);
  import "DPI-C" function int    dpi_json_as_int(input int h);
  import "DPI-C" function real   dpi_json_as_real(input int h);
  import "DPI-C" function int    dpi_json_as_bool(input int h);

  // DPI imports — create functions
  import "DPI-C" function int    dpi_json_create_string(input string val);
  import "DPI-C" function int    dpi_json_create_int_val(input int val);
  import "DPI-C" function int    dpi_json_create_float_val(input real val);
  import "DPI-C" function int    dpi_json_create_bool_val(input int val);
  import "DPI-C" function int    dpi_json_create_null();

  // DPI imports — structure access
  import "DPI-C" function int    dpi_json_get(input int h, input string key);
  import "DPI-C" function int    dpi_json_at(input int h, input int idx);
  import "DPI-C" function int    dpi_json_at_path(input int h, input string path);
  import "DPI-C" function int    dpi_json_contains(input int h, input string key);
  import "DPI-C" function int    dpi_json_empty(input int h);
  import "DPI-C" function int    dpi_json_size(input int h);
  import "DPI-C" function string dpi_json_key_at(input int h, input int idx);

  // DPI imports — modification
  import "DPI-C" function int    dpi_json_set(input int h, input string key, input int val_h);
  import "DPI-C" function int    dpi_json_push(input int h, input int val_h);
  import "DPI-C" function int    dpi_json_insert_at(input int h, input int idx, input int val_h);
  import "DPI-C" function int    dpi_json_remove(input int h, input string key);
  import "DPI-C" function int    dpi_json_remove_at(input int h, input int idx);
  import "DPI-C" function int    dpi_json_update(input int h, input int other_h);

  // DPI imports — typed set functions
  import "DPI-C" function int    dpi_json_set_string(input int h, input string key, input string value);
  import "DPI-C" function int    dpi_json_set_int(input int h, input string key, input int value);
  import "DPI-C" function int    dpi_json_set_float(input int h, input string key, input real value);
  import "DPI-C" function int    dpi_json_set_bool(input int h, input string key, input int value);
  import "DPI-C" function int    dpi_json_set_null(input int h, input string key);

  // DPI imports — serialization
  import "DPI-C" function string dpi_json_dump(input int h, input int indent);
  import "DPI-C" function int    dpi_json_dump_file(input int h, input string fname, input int indent);
  import "DPI-C" function int    dpi_json_write_file(input int h, input string path, input int indent);

  // DPI imports — error reporting
  import "DPI-C" function string dpi_serde_last_error();

  `include "sv_serde_base.svh"

  class sv_json extends sv_serde_base;

    function new();
      super.new();
    endfunction

    function void init(int handle, sv_serde_type_e serde_type);
      super.init(handle, serde_type);
    endfunction

    // --- DPI dispatch virtual overrides (one-liner delegates) ---
    function int   dpi_parse(string s);           return dpi_json_parse(s);           endfunction
    function int   dpi_new_object();              return dpi_json_new_object();       endfunction
    function int   dpi_new_array();               return dpi_json_new_array();        endfunction
    function int   dpi_create_string(string v);   return dpi_json_create_string(v);   endfunction
    function int   dpi_create_int_val(int v);     return dpi_json_create_int_val(v);  endfunction
    function int   dpi_create_float_val(real v);  return dpi_json_create_float_val(v);endfunction
    function int   dpi_create_bool_val(int v);    return dpi_json_create_bool_val(v); endfunction
    function int   dpi_create_null();             return dpi_json_create_null();      endfunction
    function int   dpi_get(int h, string k);      return dpi_json_get(h, k);          endfunction
    function int   dpi_at(int h, int i);          return dpi_json_at(h, i);           endfunction
    function int   dpi_at_path(int h, string p);  return dpi_json_at_path(h, p);      endfunction
    function int   dpi_contains(int h, string k); return dpi_json_contains(h, k);     endfunction
    function int   dpi_empty(int h);              return dpi_json_empty(h);           endfunction
    function int   dpi_size(int h);               return dpi_json_size(h);            endfunction
    function string dpi_key_at(int h, int i);     return dpi_json_key_at(h, i);       endfunction
    function int    dpi_set(int h, string k, int v);       return dpi_json_set(h, k, v);       endfunction
    function int    dpi_push(int h, int v);               return dpi_json_push(h, v);          endfunction
    function int    dpi_insert_at(int h, int i, int v);   return dpi_json_insert_at(h, i, v);  endfunction
    function int    dpi_remove(int h, string k);          return dpi_json_remove(h, k);        endfunction
    function int    dpi_remove_at(int h, int i);          return dpi_json_remove_at(h, i);     endfunction
    function int    dpi_update(int h, int o);             return dpi_json_update(h, o);        endfunction
    function int    dpi_set_string(int h, string k, string v); return dpi_json_set_string(h, k, v); endfunction
    function int    dpi_set_int(int h, string k, int v);      return dpi_json_set_int(h, k, v);      endfunction
    function int    dpi_set_float(int h, string k, real v);   return dpi_json_set_float(h, k, v);    endfunction
    function int    dpi_set_bool(int h, string k, int v);     return dpi_json_set_bool(h, k, v);     endfunction
    function int    dpi_set_null(int h, string k);            return dpi_json_set_null(h, k);        endfunction
    function string dpi_as_string(int h);     return dpi_json_as_string(h);     endfunction
    function int    dpi_as_int(int h);         return dpi_json_as_int(h);       endfunction
    function real   dpi_as_real(int h);        return dpi_json_as_real(h);      endfunction
    function int    dpi_as_bool(int h);        return dpi_json_as_bool(h);      endfunction
    function string dpi_dump(int h, int i);    return dpi_json_dump(h, i);      endfunction
    function int    dpi_dump_file(int h, string f, int i); return dpi_json_dump_file(h, f, i); endfunction
    function int    dpi_clone(int h);          return dpi_json_clone(h);        endfunction
    function void   dpi_destroy(int h);        dpi_json_destroy(h);            endfunction
    function int    dpi_is_valid(int h);       return dpi_json_is_valid(h);    endfunction
    function string dpi_last_error();          return dpi_serde_last_error();  endfunction
    function int    dpi_get_type(int h);        return dpi_json_get_type(h);   endfunction

    // --- Factory method ---
    function sv_serde_base make_child(int h, sv_serde_type_e t);
      sv_json child = new();
      child.init(h, t);
      child.m_strict_mode = this.m_strict_mode;
      return child;
    endfunction

    // --- Public accessors (shadow base _xxx methods with correct return type) ---
    function sv_json get(string key);
      sv_serde_base v = super._get(key);
      if (v == null) return null;
      $cast(get, v);
    endfunction

    function sv_json at(int idx);
      sv_serde_base v = super._at(idx);
      if (v == null) return null;
      $cast(at, v);
    endfunction

    function sv_json at_path(string path);
      sv_serde_base v = super._at_path(path);
      if (v == null) return null;
      $cast(at_path, v);
    endfunction

    function sv_json set(string key, sv_json value);
      sv_serde_base v = super._set(key, value);
      if (v == null) return null;
      $cast(set, v);
    endfunction

    function sv_json push(sv_json value);
      sv_serde_base v = super._push(value);
      if (v == null) return null;
      $cast(push, v);
    endfunction

    function sv_json insert_at(int idx, sv_json value);
      sv_serde_base v = super._insert_at(idx, value);
      if (v == null) return null;
      $cast(insert_at, v);
    endfunction

    function sv_json remove(string key);
      sv_serde_base v = super._remove(key);
      if (v == null) return null;
      $cast(remove, v);
    endfunction

    function sv_json remove_at(int idx);
      sv_serde_base v = super._remove_at(idx);
      if (v == null) return null;
      $cast(remove_at, v);
    endfunction

    function sv_json update(sv_json other);
      sv_serde_base v = super._update(other);
      if (v == null) return null;
      $cast(update, v);
    endfunction

    function sv_json clone();
      sv_serde_base v = super._clone();
      if (v == null) return null;
      $cast(clone, v);
    endfunction

    // --- Static factory methods ---
    static function sv_json parse(string input_str);
      int h = dpi_json_parse(input_str);
      if (h == 0) return null;
      sv_json result = new();
      result.init(h, sv_serde_type_e'(dpi_json_get_type(h)));
      return result;
    endfunction

    static function sv_json new_object();
      sv_json result = new();
      result.init(dpi_json_new_object(), SERDE_OBJECT);
      return result;
    endfunction

    static function sv_json new_array();
      sv_json result = new();
      result.init(dpi_json_new_array(), SERDE_ARRAY);
      return result;
    endfunction

    static function sv_json from_string(string val);
      sv_json result = new();
      result.init(dpi_json_create_string(val), SERDE_STRING);
      return result;
    endfunction

    static function sv_json from_int(int val);
      sv_json result = new();
      result.init(dpi_json_create_int_val(val), SERDE_INT);
      return result;
    endfunction

    static function sv_json from_real(real val);
      sv_json result = new();
      result.init(dpi_json_create_float_val(val), SERDE_REAL);
      return result;
    endfunction

    static function sv_json from_bool(bit val);
      sv_json result = new();
      result.init(dpi_json_create_bool_val(val ? 1 : 0), SERDE_BOOL);
      return result;
    endfunction

    static function sv_json make_null();
      sv_json result = new();
      result.init(dpi_json_create_null(), SERDE_NULL);
      return result;
    endfunction

  endclass

endpackage
