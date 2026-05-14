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

  // DPI imports — type checking
  import "DPI-C" function int    dpi_json_is_null(input int h);
  import "DPI-C" function int    dpi_json_is_boolean(input int h);
  import "DPI-C" function int    dpi_json_is_int(input int h);
  import "DPI-C" function int    dpi_json_is_real(input int h);
  import "DPI-C" function int    dpi_json_is_string(input int h);
  import "DPI-C" function int    dpi_json_is_array(input int h);
  import "DPI-C" function int    dpi_json_is_object(input int h);
  import "DPI-C" function int    dpi_json_get_type(input int h);

  // DPI imports — value extraction
  import "DPI-C" function string dpi_json_as_string(input int h);
  import "DPI-C" function int    dpi_json_as_int(input int h);
  import "DPI-C" function real   dpi_json_as_real(input int h);
  import "DPI-C" function int    dpi_json_as_bool(input int h);

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

  // DPI imports — serialization
  import "DPI-C" function string dpi_json_dump(input int h, input int indent);
  import "DPI-C" function int    dpi_json_dump_file(input int h, input string fname, input int indent);

  // Strict mode flag
  bit strict_mode = 0;

  class sv_json;
    int handle;

    function new(int h = 0);
      this.handle = h;
    endfunction

    // --- Static factory methods ---

    static function sv_json parse(string input_str);
      int h = dpi_json_parse(input_str);
      if (h == 0) return null;
      return new(h);
    endfunction

    static function sv_json new_object();
      return new(dpi_json_new_object());
    endfunction

    static function sv_json new_array();
      return new(dpi_json_new_array());
    endfunction

    static function sv_json from_string(string val);
      int h = dpi_json_parse({"\"", val, "\""});
      return new(h);
    endfunction

    static function sv_json from_int(int val);
      string s = $sformatf("%0d", val);
      int h = dpi_json_parse(s);
      return new(h);
    endfunction

    static function sv_json from_real(real val);
      string s = $sformatf("%f", val);
      int h = dpi_json_parse(s);
      return new(h);
    endfunction

    static function sv_json from_bool(bit val);
      string s = val ? "true" : "false";
      int h = dpi_json_parse(s);
      return new(h);
    endfunction

    static function sv_json make_null();
      int h = dpi_json_parse("null");
      return new(h);
    endfunction

    static function void set_strict_mode(bit enable);
      strict_mode = enable;
    endfunction

    // --- Type checking ---

    function bit is_null();
      return dpi_json_is_null(this.handle);
    endfunction

    function bit is_boolean();
      return dpi_json_is_boolean(this.handle);
    endfunction

    function bit is_int();
      return dpi_json_is_int(this.handle);
    endfunction

    function bit is_real();
      return dpi_json_is_real(this.handle);
    endfunction

    function bit is_number();
      return is_int() || is_real();
    endfunction

    function bit is_string();
      return dpi_json_is_string(this.handle);
    endfunction

    function bit is_array();
      return dpi_json_is_array(this.handle);
    endfunction

    function bit is_object();
      return dpi_json_is_object(this.handle);
    endfunction

    function sv_json_type_e get_type();
      return sv_json_type_e'(dpi_json_get_type(this.handle));
    endfunction

    // --- Value extraction ---

    function string as_string();
      if (strict_mode && !is_string()) $fatal(1, "Not a string");
      return dpi_json_as_string(this.handle);
    endfunction

    function int as_int();
      if (strict_mode && !is_int()) $fatal(1, "Not an int");
      return dpi_json_as_int(this.handle);
    endfunction

    function real as_real();
      if (strict_mode && !is_real()) $fatal(1, "Not a real");
      return dpi_json_as_real(this.handle);
    endfunction

    function bit as_bool();
      if (strict_mode && !is_boolean()) $fatal(1, "Not a boolean");
      return dpi_json_as_bool(this.handle);
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
      int h = dpi_json_get(this.handle, key);
      if (h == 0) return null;
      return new(h);
    endfunction

    function sv_json at(int idx);
      int h = dpi_json_at(this.handle, idx);
      if (h == 0) return null;
      return new(h);
    endfunction

    function sv_json at_path(string path);
      int h = dpi_json_at_path(this.handle, path);
      if (h == 0) return null;
      return new(h);
    endfunction

    function bit contains(string key);
      return dpi_json_contains(this.handle, key);
    endfunction

    function bit empty();
      return dpi_json_empty(this.handle);
    endfunction

    function int size();
      return dpi_json_size(this.handle);
    endfunction

    function string key_at(int idx);
      return dpi_json_key_at(this.handle, idx);
    endfunction

    function void get_keys(output string keys[$]);
      keys = {};
      if (!is_object()) return;
      int n = size();
      for (int i = 0; i < n; i++) begin
        keys.push_back(key_at(i));
      end
    endfunction

    // --- Modification (immutable) ---

    function sv_json set(string key, sv_json value);
      int h = dpi_json_set(this.handle, key, value.handle);
      if (h == 0) return null;
      return new(h);
    endfunction

    function sv_json push(sv_json value);
      int h = dpi_json_push(this.handle, value.handle);
      if (h == 0) return null;
      return new(h);
    endfunction

    function sv_json insert_at(int idx, sv_json value);
      int h = dpi_json_insert_at(this.handle, idx, value.handle);
      if (h == 0) return null;
      return new(h);
    endfunction

    function sv_json remove(string key);
      int h = dpi_json_remove(this.handle, key);
      if (h == 0) return null;
      return new(h);
    endfunction

    function sv_json remove_at(int idx);
      int h = dpi_json_remove_at(this.handle, idx);
      if (h == 0) return null;
      return new(h);
    endfunction

    function sv_json update(sv_json other);
      int h = dpi_json_update(this.handle, other.handle);
      if (h == 0) return null;
      return new(h);
    endfunction

    // --- Serialization ---

    function string dump(string fname = "", int indent = 2);
      if (fname != "") begin
        int rc = dpi_json_dump_file(this.handle, fname, indent);
        return (rc == 0) ? "ok" : "error";
      end
      return dpi_json_dump(this.handle, indent);
    endfunction

    // Alias for dump with file
    function int dump_file(string fname, int indent = 2);
      return dpi_json_dump_file(this.handle, fname, indent);
    endfunction

  endclass

endpackage
