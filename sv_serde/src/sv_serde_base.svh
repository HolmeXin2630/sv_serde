// sv_serde_base — shared base class for sv_json and sv_yaml
//
// This is an `include file; the includer must have sv_serde_type_e and
// SERDE_* constants in scope (via import sv_serde_pkg::*).
//
// Internal accessor/modifier/clone methods are prefixed with '_' and
// return sv_serde_base.  Each concrete subclass provides the public
// versions (without '_') returning the correct concrete type.  The public
// versions call the protected '_' methods via super and $cast the result.
// This avoids relying on SV covariant return types which are not
// universally supported across simulators.

virtual class sv_serde_base;
  protected int m_handle;
  protected sv_serde_type_e m_type;
  protected bit m_strict_mode;
  protected static bit s_default_strict_mode = 0;

  // -----------------------------------------------------------------------
  // Constructor (no-arg, then init() — Verilator-compatible two-phase init)
  // -----------------------------------------------------------------------
  protected function new();
    m_handle = 0;
    m_type = SERDE_NULL;
    m_strict_mode = s_default_strict_mode;
  endfunction

  protected function void init(int handle, sv_serde_type_e serde_type);
    m_handle = handle;
    m_type = serde_type;
  endfunction

  // -----------------------------------------------------------------------
  // Pure virtual DPI dispatch — one override per concrete subclass
  // -----------------------------------------------------------------------
  pure virtual function int   dpi_parse(string input_str);
  pure virtual function int   dpi_new_object();
  pure virtual function int   dpi_new_array();
  pure virtual function int   dpi_create_string(string val);
  pure virtual function int   dpi_create_int_val(int val);
  pure virtual function int   dpi_create_float_val(real val);
  pure virtual function int   dpi_create_bool_val(int val);
  pure virtual function int   dpi_create_null();
  pure virtual function int   dpi_get(int h, string key);
  pure virtual function int   dpi_at(int h, int idx);
  pure virtual function int   dpi_at_path(int h, string path);
  pure virtual function int   dpi_contains(int h, string key);
  pure virtual function int   dpi_empty(int h);
  pure virtual function int   dpi_size(int h);
  pure virtual function string dpi_key_at(int h, int idx);
  pure virtual function int    dpi_set(int h, string key, int val_h);
  pure virtual function int    dpi_push(int h, int val_h);
  pure virtual function int    dpi_insert_at(int h, int idx, int val_h);
  pure virtual function int    dpi_remove(int h, string key);
  pure virtual function int    dpi_remove_at(int h, int idx);
  pure virtual function int    dpi_update(int h, int other_h);
  pure virtual function int    dpi_set_string(int h, string key, string value);
  pure virtual function int    dpi_set_int(int h, string key, int value);
  pure virtual function int    dpi_set_float(int h, string key, real value);
  pure virtual function int    dpi_set_bool(int h, string key, int value);
  pure virtual function int    dpi_set_null(int h, string key);
  pure virtual function string dpi_as_string(int h);
  pure virtual function int    dpi_as_int(int h);
  pure virtual function real   dpi_as_real(int h);
  pure virtual function int    dpi_as_bool(int h);
  pure virtual function string dpi_dump(int h, int indent);
  pure virtual function int    dpi_dump_file(int h, string fname, int indent);
  pure virtual function int    dpi_clone(int h);
  pure virtual function void   dpi_destroy(int h);
  pure virtual function int    dpi_is_valid(int h);
  pure virtual function string dpi_last_error();
  pure virtual function int    dpi_get_type(int h);

  // -----------------------------------------------------------------------
  // Strict mode — per-instance with static default
  // -----------------------------------------------------------------------
  static function void set_default_strict_mode(bit enable);
    s_default_strict_mode = enable;
  endfunction

  function void set_strict_mode(bit enable);
    m_strict_mode = enable;
  endfunction

  // -----------------------------------------------------------------------
  // Type checking (uses cached m_type, no DPI calls)
  // -----------------------------------------------------------------------
  function bit is_null();    return m_type == SERDE_NULL;    endfunction
  function bit is_boolean(); return m_type == SERDE_BOOL;    endfunction
  function bit is_int();     return m_type == SERDE_INT;     endfunction
  function bit is_real();    return m_type == SERDE_REAL;    endfunction
  function bit is_string();  return m_type == SERDE_STRING;  endfunction
  function bit is_array();   return m_type == SERDE_ARRAY;   endfunction
  function bit is_object();  return m_type == SERDE_OBJECT;  endfunction

  function bit is_number();
    return is_int() || is_real();
  endfunction

  function sv_serde_type_e get_type();
    return m_type;
  endfunction

  // -----------------------------------------------------------------------
  // Value extraction
  // -----------------------------------------------------------------------
  function string as_string();
    if (m_strict_mode && !is_string())
      $fatal(1, "serde strict: expected string, got type %0d", m_type);
    return dpi_as_string(m_handle);
  endfunction

  function int as_int();
    if (m_strict_mode && !is_int())
      $fatal(1, "serde strict: expected int, got type %0d", m_type);
    return dpi_as_int(m_handle);
  endfunction

  function real as_real();
    if (m_strict_mode && !is_real())
      $fatal(1, "serde strict: expected real, got type %0d", m_type);
    return dpi_as_real(m_handle);
  endfunction

  function bit as_bool();
    if (m_strict_mode && !is_boolean())
      $fatal(1, "serde strict: expected bool, got type %0d", m_type);
    return dpi_as_bool(m_handle);
  endfunction

  // -----------------------------------------------------------------------
  // Value access with defaults (calls _get(), returns scalars)
  // -----------------------------------------------------------------------
  function string value_string(string key, string default_val);
    sv_serde_base v = _get(key);
    if (v == null) return default_val;
    if (!v.is_string()) return default_val;
    return v.as_string();
  endfunction

  function int value_int(string key, int default_val);
    sv_serde_base v = _get(key);
    if (v == null) return default_val;
    if (!v.is_int()) return default_val;
    return v.as_int();
  endfunction

  function real value_real(string key, real default_val);
    sv_serde_base v = _get(key);
    if (v == null) return default_val;
    if (!v.is_real()) return default_val;
    return v.as_real();
  endfunction

  function bit value_bool(string key, bit default_val);
    sv_serde_base v = _get(key);
    if (v == null) return default_val;
    if (!v.is_boolean()) return default_val;
    return v.as_bool();
  endfunction

  // -----------------------------------------------------------------------
  // Structure queries (return scalars — safe in base class)
  // -----------------------------------------------------------------------
  function bit contains(string key);
    return dpi_contains(m_handle, key);
  endfunction

  function bit empty();
    return dpi_empty(m_handle);
  endfunction

  function int size();
    return dpi_size(m_handle);
  endfunction

  function string key_at(int idx);
    return dpi_key_at(m_handle, idx);
  endfunction

  function void get_keys(output string keys[$]);
    int n;
    keys = {};
    if (!is_object()) return;
    n = size();
    for (int i = 0; i < n; i++)
      keys.push_back(key_at(i));
  endfunction

  // -----------------------------------------------------------------------
  // Internal accessors — protected, return sv_serde_base.
  // Concrete subclasses provide public wrappers that call super._xxx()
  // and $cast to the correct concrete type.
  // -----------------------------------------------------------------------
  protected function sv_serde_base _get(string key);
    int h = dpi_get(m_handle, key);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  protected function sv_serde_base _at(int idx);
    int h = dpi_at(m_handle, idx);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  protected function sv_serde_base _at_path(string path);
    int h = dpi_at_path(m_handle, path);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  // -----------------------------------------------------------------------
  // Internal modifiers — protected, return sv_serde_base.
  // -----------------------------------------------------------------------
  protected function sv_serde_base _set(string key, sv_serde_base value);
    int h = dpi_set(m_handle, key, value.m_handle);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  protected function sv_serde_base _push(sv_serde_base value);
    int h = dpi_push(m_handle, value.m_handle);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  protected function sv_serde_base _insert_at(int idx, sv_serde_base value);
    int h = dpi_insert_at(m_handle, idx, value.m_handle);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  protected function sv_serde_base _remove(string key);
    int h = dpi_remove(m_handle, key);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  protected function sv_serde_base _remove_at(int idx);
    int h = dpi_remove_at(m_handle, idx);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  protected function sv_serde_base _update(sv_serde_base other);
    int h = dpi_update(m_handle, other.m_handle);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------
  function string dump(string fname = "", int indent = 2);
    if (fname != "") begin
      int rc = dpi_dump_file(m_handle, fname, indent);
      return (rc == 0) ? "ok" : "error";
    end
    return dpi_dump(m_handle, indent);
  endfunction

  function int dump_file(string fname, int indent = 2);
    return dpi_dump_file(m_handle, fname, indent);
  endfunction

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------
  protected function sv_serde_base _clone();
    int h = dpi_clone(m_handle);
    if (h == 0) return null;
    return make_child(h, sv_serde_type_e'(dpi_get_type(h)));
  endfunction

  function void destroy();
    dpi_destroy(m_handle);
    m_handle = 0;
  endfunction

  function bit is_valid();
    return dpi_is_valid(m_handle);
  endfunction

  // -----------------------------------------------------------------------
  // Error reporting
  // -----------------------------------------------------------------------
  function string last_error();
    return dpi_last_error();
  endfunction

  // -----------------------------------------------------------------------
  // Abstract factory — subclass returns correctly-typed child object
  // -----------------------------------------------------------------------
  pure virtual function sv_serde_base make_child(int h, sv_serde_type_e t);

endclass
