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

  // DPI imports — type checking
  import "DPI-C" function int    dpi_yaml_is_null(input int h);
  import "DPI-C" function int    dpi_yaml_is_boolean(input int h);
  import "DPI-C" function int    dpi_yaml_is_int(input int h);
  import "DPI-C" function int    dpi_yaml_is_real(input int h);
  import "DPI-C" function int    dpi_yaml_is_string(input int h);
  import "DPI-C" function int    dpi_yaml_is_array(input int h);
  import "DPI-C" function int    dpi_yaml_is_object(input int h);
  import "DPI-C" function int    dpi_yaml_get_type(input int h);

  // DPI imports — value extraction
  import "DPI-C" function string dpi_yaml_as_string(input int h);
  import "DPI-C" function int    dpi_yaml_as_int(input int h);
  import "DPI-C" function real   dpi_yaml_as_real(input int h);
  import "DPI-C" function int    dpi_yaml_as_bool(input int h);

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

  // DPI imports — serialization
  import "DPI-C" function string dpi_yaml_dump(input int h, input int indent);
  import "DPI-C" function int    dpi_yaml_dump_file(input int h, input string fname, input int indent);

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

  class sv_yaml;
    int handle;
    function new(int h = 0);
      this.handle = h;
    endfunction

    static function sv_yaml parse(string input_str);
      int h = dpi_yaml_parse(input_str);
      if (h == 0) return null;
      return new(h);
    endfunction

    static function sv_yaml new_object();
      return new(dpi_yaml_new_object());
    endfunction

    static function sv_yaml new_array();
      return new(dpi_yaml_new_array());
    endfunction

    static function sv_yaml from_string(string val);
      int h = dpi_yaml_parse({"\"", val, "\""});
      return new(h);
    endfunction

    static function sv_yaml from_int(int val);
      string s = $sformatf("%0d", val);
      int h = dpi_yaml_parse(s);
      return new(h);
    endfunction

    static function sv_yaml from_real(real val);
      string s = $sformatf("%f", val);
      int h = dpi_yaml_parse(s);
      return new(h);
    endfunction

    static function sv_yaml from_bool(bit val);
      string s = val ? "true" : "false";
      int h = dpi_yaml_parse(s);
      return new(h);
    endfunction

    static function sv_yaml make_null();
      int h = dpi_yaml_parse("null");
      return new(h);
    endfunction

    function bit is_null(); return dpi_yaml_is_null(this.handle); endfunction
    function bit is_boolean(); return dpi_yaml_is_boolean(this.handle); endfunction
    function bit is_int(); return dpi_yaml_is_int(this.handle); endfunction
    function bit is_real(); return dpi_yaml_is_real(this.handle); endfunction
    function bit is_string(); return dpi_yaml_is_string(this.handle); endfunction
    function bit is_array(); return dpi_yaml_is_array(this.handle); endfunction
    function bit is_object(); return dpi_yaml_is_object(this.handle); endfunction
    function sv_yaml_type_e get_type(); return sv_yaml_type_e'(dpi_yaml_get_type(this.handle)); endfunction

    function string as_string(); return dpi_yaml_as_string(this.handle); endfunction
    function int as_int(); return dpi_yaml_as_int(this.handle); endfunction
    function real as_real(); return dpi_yaml_as_real(this.handle); endfunction
    function bit as_bool(); return dpi_yaml_as_bool(this.handle); endfunction

    function sv_yaml get(string key);
      int h = dpi_yaml_get(this.handle, key);
      if (h == 0) return null;
      return new(h);
    endfunction

    function sv_yaml at(int idx);
      int h = dpi_yaml_at(this.handle, idx);
      if (h == 0) return null;
      return new(h);
    endfunction

    function sv_yaml at_path(string path);
      int h = dpi_yaml_at_path(this.handle, path);
      if (h == 0) return null;
      return new(h);
    endfunction

    function bit contains(string key); return dpi_yaml_contains(this.handle, key); endfunction
    function bit empty(); return dpi_yaml_empty(this.handle); endfunction
    function int size(); return dpi_yaml_size(this.handle); endfunction
    function string key_at(int idx); return dpi_yaml_key_at(this.handle, idx); endfunction

    function sv_yaml set(string key, sv_yaml value);
      int h = dpi_yaml_set(this.handle, key, value.handle);
      if (h == 0) return null;
      return new(h);
    endfunction

    function sv_yaml push(sv_yaml value);
      int h = dpi_yaml_push(this.handle, value.handle);
      if (h == 0) return null;
      return new(h);
    endfunction

    function sv_yaml remove(string key);
      int h = dpi_yaml_remove(this.handle, key);
      if (h == 0) return null;
      return new(h);
    endfunction

    function string dump(string fname = "", int indent = 2);
      if (fname != "") begin
        int rc = dpi_yaml_dump_file(this.handle, fname, indent);
        return (rc == 0) ? "ok" : "error";
      end
      return dpi_yaml_dump(this.handle, indent);
    endfunction

    // YAML-specific
    static function sv_yaml yaml_parse_all(string input_str);
      int h = dpi_yaml_parse_all(input_str);
      if (h == 0) return null;
      return new(h);
    endfunction

    function string yaml_comments(); return dpi_yaml_comments(this.handle); endfunction
    function sv_yaml yaml_set_comment(string text);
      int h = dpi_yaml_set_comment(this.handle, text);
      if (h == 0) return null;
      return new(h);
    endfunction

    function string yaml_anchor(); return dpi_yaml_anchor(this.handle); endfunction
    function sv_yaml yaml_set_anchor(string name);
      int h = dpi_yaml_set_anchor(this.handle, name);
      if (h == 0) return null;
      return new(h);
    endfunction

    function string yaml_alias(); return dpi_yaml_alias(this.handle); endfunction
    function string yaml_tag(); return dpi_yaml_tag(this.handle); endfunction
    function sv_yaml yaml_set_tag(string tag);
      int h = dpi_yaml_set_tag(this.handle, tag);
      if (h == 0) return null;
      return new(h);
    endfunction

    function string yaml_dump_flow(); return dpi_yaml_dump_flow(this.handle); endfunction
    function string yaml_dump_with_comments(); return dpi_yaml_dump_with_comments(this.handle); endfunction

  endclass

endpackage
