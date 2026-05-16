package sv_json_pkg;

  // Type enum
  typedef enum int {
    SV_JSON_NULL    = 0,
    SV_JSON_BOOLEAN = 1,
    SV_JSON_INT     = 2,
    SV_JSON_REAL    = 3,
    SV_JSON_STRING  = 4,
    SV_JSON_ARRAY   = 5,
    SV_JSON_OBJECT  = 6
  } sv_json_type_e;

  // DPI imports — lifecycle
  import "DPI-C" function int    dpi_json_new_object();
  import "DPI-C" function int    dpi_json_new_array();
  import "DPI-C" function int    dpi_json_parse(input string input_str);
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

  // DPI imports — create functions (for from_* factory methods)
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

  // Strict mode flag
  bit strict_mode = 0;

  class sv_json;
    local int m_handle;
    local sv_json_type_e m_type;

    local function new(int handle, sv_json_type_e json_type);
      m_handle = handle;
      m_type = json_type;
    endfunction

    // --- Static factory methods ---

    static function sv_json parse(string input_str);
      int h = dpi_json_parse(input_str);
      sv_json tmp;
      if (h == 0) return null;
      tmp = new(h, sv_json_type_e'(dpi_json_get_type(h)));
      return tmp;
    endfunction

    static function sv_json new_object();
      sv_json tmp = new(dpi_json_new_object(), SV_JSON_OBJECT);
      return tmp;
    endfunction

    static function sv_json new_array();
      sv_json tmp = new(dpi_json_new_array(), SV_JSON_ARRAY);
      return tmp;
    endfunction

    static function sv_json from_string(string val);
      sv_json tmp = new(dpi_json_create_string(val), SV_JSON_STRING);
      return tmp;
    endfunction

    static function sv_json from_int(int val);
      sv_json tmp = new(dpi_json_create_int_val(val), SV_JSON_INT);
      return tmp;
    endfunction

    static function sv_json from_real(real val);
      sv_json tmp = new(dpi_json_create_float_val(val), SV_JSON_REAL);
      return tmp;
    endfunction

    static function sv_json from_bool(bit val);
      sv_json tmp = new(dpi_json_create_bool_val(val ? 1 : 0), SV_JSON_BOOLEAN);
      return tmp;
    endfunction

    static function sv_json make_null();
      sv_json tmp = new(dpi_json_create_null(), SV_JSON_NULL);
      return tmp;
    endfunction

    static function void set_strict_mode(bit enable);
      strict_mode = enable;
    endfunction

    // --- Type checking (uses cached m_type) ---

    function bit is_null();    return m_type == SV_JSON_NULL;    endfunction
    function bit is_boolean(); return m_type == SV_JSON_BOOLEAN; endfunction
    function bit is_int();     return m_type == SV_JSON_INT;     endfunction
    function bit is_real();    return m_type == SV_JSON_REAL;    endfunction
    function bit is_string();  return m_type == SV_JSON_STRING;  endfunction
    function bit is_array();   return m_type == SV_JSON_ARRAY;   endfunction
    function bit is_object();  return m_type == SV_JSON_OBJECT;  endfunction

    function bit is_number();
      return is_int() || is_real();
    endfunction

    function sv_json_type_e get_type();
      return m_type;
    endfunction

    // --- Value extraction ---

    function string as_string();
      if (strict_mode && !is_string()) $fatal(1, "Not a string");
      return dpi_json_as_string(m_handle);
    endfunction

    function int as_int();
      if (strict_mode && !is_int()) $fatal(1, "Not an int");
      return dpi_json_as_int(m_handle);
    endfunction

    function real as_real();
      if (strict_mode && !is_real()) $fatal(1, "Not a real");
      return dpi_json_as_real(m_handle);
    endfunction

    function bit as_bool();
      if (strict_mode && !is_boolean()) $fatal(1, "Not a boolean");
      return dpi_json_as_bool(m_handle);
    endfunction

    function string value_string(string key, string default_val);
      sv_json v = get(key);
      if (v == null || !v.is_string()) return default_val;
      return v.as_string();
    endfunction

    function int value_int(string key, int default_val);
      sv_json v = get(key);
      if (v == null || !v.is_int()) return default_val;
      return v.as_int();
    endfunction

    function real value_real(string key, real default_val);
      sv_json v = get(key);
      if (v == null || !v.is_real()) return default_val;
      return v.as_real();
    endfunction

    function bit value_bool(string key, bit default_val);
      sv_json v = get(key);
      if (v == null || !v.is_boolean()) return default_val;
      return v.as_bool();
    endfunction

    // --- Structure access ---

    function sv_json get(string key);
      int h = dpi_json_get(m_handle, key);
      sv_json tmp;
      if (h == 0) return null;
      tmp = new(h, sv_json_type_e'(dpi_json_get_type(h)));
      return tmp;
    endfunction

    function sv_json at(int idx);
      int h = dpi_json_at(m_handle, idx);
      sv_json tmp;
      if (h == 0) return null;
      tmp = new(h, sv_json_type_e'(dpi_json_get_type(h)));
      return tmp;
    endfunction

    function sv_json at_path(string path);
      int h = dpi_json_at_path(m_handle, path);
      sv_json tmp;
      if (h == 0) return null;
      tmp = new(h, sv_json_type_e'(dpi_json_get_type(h)));
      return tmp;
    endfunction

    function bit contains(string key);
      return dpi_json_contains(m_handle, key);
    endfunction

    function bit empty();
      return dpi_json_empty(m_handle);
    endfunction

    function int size();
      return dpi_json_size(m_handle);
    endfunction

    function string key_at(int idx);
      return dpi_json_key_at(m_handle, idx);
    endfunction

    function void get_keys(output string keys[$]);
      int n;
      keys = {};
      if (!is_object()) return;
      n = size();
      for (int i = 0; i < n; i++) begin
        keys.push_back(key_at(i));
      end
    endfunction

    // --- Modification (immutable) ---

    function sv_json set(string key, sv_json value);
      int h = dpi_json_set(m_handle, key, value.m_handle);
      sv_json tmp;
      if (h == 0) return null;
      tmp = new(h, sv_json_type_e'(dpi_json_get_type(h)));
      return tmp;
    endfunction

    function sv_json push(sv_json value);
      int h = dpi_json_push(m_handle, value.m_handle);
      sv_json tmp;
      if (h == 0) return null;
      tmp = new(h, sv_json_type_e'(dpi_json_get_type(h)));
      return tmp;
    endfunction

    function sv_json insert_at(int idx, sv_json value);
      int h = dpi_json_insert_at(m_handle, idx, value.m_handle);
      sv_json tmp;
      if (h == 0) return null;
      tmp = new(h, sv_json_type_e'(dpi_json_get_type(h)));
      return tmp;
    endfunction

    function sv_json remove(string key);
      int h = dpi_json_remove(m_handle, key);
      sv_json tmp;
      if (h == 0) return null;
      tmp = new(h, sv_json_type_e'(dpi_json_get_type(h)));
      return tmp;
    endfunction

    function sv_json remove_at(int idx);
      int h = dpi_json_remove_at(m_handle, idx);
      sv_json tmp;
      if (h == 0) return null;
      tmp = new(h, sv_json_type_e'(dpi_json_get_type(h)));
      return tmp;
    endfunction

    function sv_json update(sv_json other);
      int h = dpi_json_update(m_handle, other.m_handle);
      sv_json tmp;
      if (h == 0) return null;
      tmp = new(h, sv_json_type_e'(dpi_json_get_type(h)));
      return tmp;
    endfunction

    // --- Serialization ---

    function string dump(string fname = "", int indent = 2);
      if (fname != "") begin
        int rc = dpi_json_dump_file(m_handle, fname, indent);
        return (rc == 0) ? "ok" : "error";
      end
      return dpi_json_dump(m_handle, indent);
    endfunction

    // Alias for dump with file
    function int dump_file(string fname, int indent = 2);
      return dpi_json_dump_file(m_handle, fname, indent);
    endfunction

  endclass

endpackage
