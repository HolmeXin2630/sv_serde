package sv_yaml_pkg;

  typedef enum int {
    SV_YAML_NULL    = 0,
    SV_YAML_BOOLEAN = 1,
    SV_YAML_INT     = 2,
    SV_YAML_REAL    = 3,
    SV_YAML_STRING  = 4,
    SV_YAML_ARRAY   = 5,
    SV_YAML_OBJECT  = 6
  } sv_yaml_type_e;

  // DPI imports — lifecycle
  import "DPI-C" function int    dpi_yaml_new_object();
  import "DPI-C" function int    dpi_yaml_new_array();
  import "DPI-C" function int    dpi_yaml_parse(input string input_str);
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

  // Strict mode flag
  bit strict_mode = 0;

  class sv_yaml;
    local int m_handle;
    local sv_yaml_type_e m_type;

    local function new(int handle, sv_yaml_type_e yaml_type);
      m_handle = handle;
      m_type = yaml_type;
    endfunction

    static function sv_yaml parse(string input_str);
      int h = dpi_yaml_parse(input_str);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    static function sv_yaml new_object();
      return new(dpi_yaml_new_object(), SV_YAML_OBJECT);
    endfunction

    static function sv_yaml new_array();
      return new(dpi_yaml_new_array(), SV_YAML_ARRAY);
    endfunction

    static function sv_yaml from_string(string val);
      return new(dpi_yaml_create_string(val), SV_YAML_STRING);
    endfunction

    static function sv_yaml from_int(int val);
      return new(dpi_yaml_create_int_val(val), SV_YAML_INT);
    endfunction

    static function sv_yaml from_real(real val);
      return new(dpi_yaml_create_float_val(val), SV_YAML_REAL);
    endfunction

    static function sv_yaml from_bool(bit val);
      return new(dpi_yaml_create_bool_val(val ? 1 : 0), SV_YAML_BOOLEAN);
    endfunction

    static function sv_yaml make_null();
      return new(dpi_yaml_create_null(), SV_YAML_NULL);
    endfunction

    static function void set_strict_mode(bit enable);
      strict_mode = enable;
    endfunction

    function bit is_null();    return m_type == SV_YAML_NULL;    endfunction
    function bit is_boolean(); return m_type == SV_YAML_BOOLEAN; endfunction
    function bit is_int();     return m_type == SV_YAML_INT;     endfunction
    function bit is_real();    return m_type == SV_YAML_REAL;    endfunction
    function bit is_string();  return m_type == SV_YAML_STRING;  endfunction
    function bit is_array();   return m_type == SV_YAML_ARRAY;   endfunction
    function bit is_object();  return m_type == SV_YAML_OBJECT;  endfunction

    function bit is_number();
      return is_int() || is_real();
    endfunction

    function sv_yaml_type_e get_type(); return m_type; endfunction

    function string as_string();
      if (strict_mode && !is_string()) $fatal(1, "Not a string");
      return dpi_yaml_as_string(m_handle);
    endfunction

    function int as_int();
      if (strict_mode && !is_int()) $fatal(1, "Not an int");
      return dpi_yaml_as_int(m_handle);
    endfunction

    function real as_real();
      if (strict_mode && !is_real()) $fatal(1, "Not a real");
      return dpi_yaml_as_real(m_handle);
    endfunction

    function bit as_bool();
      if (strict_mode && !is_boolean()) $fatal(1, "Not a boolean");
      return dpi_yaml_as_bool(m_handle);
    endfunction

    function string value_string(string key, string default_val);
      sv_yaml v = get(key);
      if (v == null || !v.is_string()) return default_val;
      return v.as_string();
    endfunction

    function int value_int(string key, int default_val);
      sv_yaml v = get(key);
      if (v == null || !v.is_int()) return default_val;
      return v.as_int();
    endfunction

    function real value_real(string key, real default_val);
      sv_yaml v = get(key);
      if (v == null || !v.is_real()) return default_val;
      return v.as_real();
    endfunction

    function bit value_bool(string key, bit default_val);
      sv_yaml v = get(key);
      if (v == null || !v.is_boolean()) return default_val;
      return v.as_bool();
    endfunction

    function sv_yaml get(string key);
      int h = dpi_yaml_get(m_handle, key);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function sv_yaml at(int idx);
      int h = dpi_yaml_at(m_handle, idx);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function sv_yaml at_path(string path);
      int h = dpi_yaml_at_path(m_handle, path);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function bit contains(string key); return dpi_yaml_contains(m_handle, key); endfunction
    function bit empty(); return dpi_yaml_empty(m_handle); endfunction
    function int size(); return dpi_yaml_size(m_handle); endfunction
    function string key_at(int idx); return dpi_yaml_key_at(m_handle, idx); endfunction

    function void get_keys(output string keys[$]);
      keys = {};
      if (!is_object()) return;
      int n = size();
      for (int i = 0; i < n; i++) begin
        keys.push_back(key_at(i));
      end
    endfunction

    function sv_yaml set(string key, sv_yaml value);
      int h = dpi_yaml_set(m_handle, key, value.m_handle);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function sv_yaml push(sv_yaml value);
      int h = dpi_yaml_push(m_handle, value.m_handle);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function sv_yaml insert_at(int idx, sv_yaml value);
      int h = dpi_yaml_insert_at(m_handle, idx, value.m_handle);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function sv_yaml remove(string key);
      int h = dpi_yaml_remove(m_handle, key);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function sv_yaml remove_at(int idx);
      int h = dpi_yaml_remove_at(m_handle, idx);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function sv_yaml update(sv_yaml other);
      int h = dpi_yaml_update(m_handle, other.m_handle);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function string dump(string fname = "", int indent = 2);
      if (fname != "") begin
        int rc = dpi_yaml_dump_file(m_handle, fname, indent);
        return (rc == 0) ? "ok" : "error";
      end
      return dpi_yaml_dump(m_handle, indent);
    endfunction

    function int dump_file(string fname, int indent = 2);
      return dpi_yaml_dump_file(m_handle, fname, indent);
    endfunction

    // YAML-specific
    static function sv_yaml yaml_parse_all(string input_str);
      int h = dpi_yaml_parse_all(input_str);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function string yaml_comments(); return dpi_yaml_comments(m_handle); endfunction
    function sv_yaml yaml_set_comment(string text);
      int h = dpi_yaml_set_comment(m_handle, text);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function string yaml_anchor(); return dpi_yaml_anchor(m_handle); endfunction
    function sv_yaml yaml_set_anchor(string name);
      int h = dpi_yaml_set_anchor(m_handle, name);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function string yaml_alias(); return dpi_yaml_alias(m_handle); endfunction
    function string yaml_tag(); return dpi_yaml_tag(m_handle); endfunction
    function sv_yaml yaml_set_tag(string tag);
      int h = dpi_yaml_set_tag(m_handle, tag);
      if (h == 0) return null;
      return new(h, sv_yaml_type_e'(dpi_yaml_get_type(h)));
    endfunction

    function string yaml_dump_flow(); return dpi_yaml_dump_flow(m_handle); endfunction
    function string yaml_dump_with_comments(); return dpi_yaml_dump_with_comments(m_handle); endfunction

  endclass

endpackage
