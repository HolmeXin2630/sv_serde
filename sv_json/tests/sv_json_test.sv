module sv_json_test;
  int pass_count = 0;
  int fail_count = 0;

  `include "serde_test_helpers.sv"

  // DPI imports — lifecycle
  import "DPI-C" function int    dpi_json_new_object();
  import "DPI-C" function int    dpi_json_new_array();
  import "DPI-C" function int    dpi_json_parse(input string input_str);
  import "DPI-C" function void   dpi_json_destroy(input int h);
  import "DPI-C" function int    dpi_json_clone(input int h);
  import "DPI-C" function void   dpi_json_free(input int h);
  import "DPI-C" function int    dpi_json_is_valid(input int h);

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

  // DPI imports — typed set
  import "DPI-C" function int    dpi_json_set_string(input int h, input string key, input string value);
  import "DPI-C" function int    dpi_json_set_int(input int h, input string key, input int value);
  import "DPI-C" function int    dpi_json_set_float(input int h, input string key, input real value);
  import "DPI-C" function int    dpi_json_set_bool(input int h, input string key, input int value);
  import "DPI-C" function int    dpi_json_set_null(input int h, input string key);

  // DPI imports — serialization
  import "DPI-C" function string dpi_json_dump(input int h, input int indent);
  import "DPI-C" function int    dpi_json_dump_file(input int h, input string fname, input int indent);
  import "DPI-C" function int    dpi_json_write_file(input int h, input string path, input int indent);

  initial begin
    int j;
    int h;
    int el0;
    string pretty;
    string compact;
    int x_h;
    int y_h;
    int z_h;

    // --- Parse ---
    j = dpi_json_parse("{\"name\":\"Alice\",\"age\":30}");
    check_bit("parse: not null", (j != 0) ? 1 : 0, 1);
    check_bit("parse: is object", dpi_json_get_type(j), 6);
    check_int("parse: size", dpi_json_size(j), 2);

    // --- Get ---
    h = dpi_json_get(j, "name");
    check_bit("get: not null", (h != 0) ? 1 : 0, 1);
    check("get: name", dpi_json_as_string(h), "Alice");

    h = dpi_json_get(j, "age");
    check_int("get: age", dpi_json_as_int(h), 30);

    // --- Missing key ---
    h = dpi_json_get(j, "missing");
    check_bit("get: missing key returns null", (h == 0) ? 1 : 0, 1);

    // --- Type checking ---
    check_bit("get_type on object", dpi_json_get_type(j), 6);

    h = dpi_json_get(j, "name");
    check_bit("get_type on string", dpi_json_get_type(h), 4);

    h = dpi_json_get(j, "age");
    check_bit("get_type on int", dpi_json_get_type(h), 2);

    // --- from_int, from_real, from_bool, from_string, make_null ---
    h = dpi_json_create_int_val(42);
    check_int("from_int", dpi_json_as_int(h), 42);

    h = dpi_json_create_float_val(3.14);
    check_real("from_real", dpi_json_as_real(h), 3.14);

    h = dpi_json_create_bool_val(1);
    check_bit("from_bool true", dpi_json_as_bool(h), 1);

    h = dpi_json_create_string("hello");
    check("from_string", dpi_json_as_string(h), "hello");

    h = dpi_json_create_null();
    check_bit("make_null is_null", dpi_json_get_type(h), 0);

    // --- new_object, new_array ---
    h = dpi_json_new_object();
    check_bit("new_object is_object", dpi_json_get_type(h), 6);
    check_bit("new_object empty", dpi_json_empty(h), 1);

    h = dpi_json_new_array();
    check_bit("new_array is_array", dpi_json_get_type(h), 5);
    check_bit("new_array empty", dpi_json_empty(h), 1);

    // --- Parse array ---
    h = dpi_json_parse("[1,2,3]");
    check_int("parse array size", dpi_json_size(h), 3);
    el0 = dpi_json_at(h, 0);
    check_int("parse array at(0)", dpi_json_as_int(el0), 1);

    // --- Dump ---
    h = dpi_json_parse("{\"name\":\"Alice\",\"age\":30}");
    pretty = dpi_json_dump(h, 2);
    check_bit("dump not empty", (pretty.len() > 0) ? 1 : 0, 1);

    compact = dpi_json_dump(h, -1);
    check("compact dump", compact, "{\"age\":30,\"name\":\"Alice\"}");

    // --- value_* with defaults ---
    h = dpi_json_parse("{\"x\":10}");
    x_h = dpi_json_get(h, "x");
    check_int("value_int present", (x_h != 0) ? dpi_json_as_int(x_h) : 0, 10);
    y_h = dpi_json_get(h, "y");
    check_int("value_int missing", (y_h != 0) ? dpi_json_as_int(y_h) : 99, 99);
    z_h = dpi_json_get(h, "z");
    check("value_string missing", (z_h != 0) ? dpi_json_as_string(z_h) : "def", "def");

    // --- Structure access: contains ---
    j = dpi_json_parse("{\"a\":1,\"b\":2}");
    check_bit("contains existing", dpi_json_contains(j, "a"), 1);
    check_bit("contains missing", dpi_json_contains(j, "nope"), 0);

    // --- Structure access: key_at ---
    check("key_at(0)", dpi_json_key_at(j, 0), "a");

    // --- Structure access: at_path ---
    begin
      int nested, path_result, arr, arr_path, missing_path;
      nested = dpi_json_parse("{\"a\":{\"b\":{\"c\":42}}}");
      path_result = dpi_json_at_path(nested, "/a/b/c");
      check_int("at_path nested", dpi_json_as_int(path_result), 42);

      arr = dpi_json_parse("[[1,2],[3,4]]");
      arr_path = dpi_json_at_path(arr, "/1/0");
      check_int("at_path array", dpi_json_as_int(arr_path), 3);

      missing_path = dpi_json_at_path(j, "/nonexistent");
      check_bit("at_path missing null", (missing_path == 0) ? 1 : 0, 1);
    end

    // --- Modification: set ---
    begin
      int orig, modified, b_val;
      orig = dpi_json_parse("{\"a\":1}");
      modified = dpi_json_set(orig, "b", dpi_json_parse("2"));
      check_int("set: original unchanged", dpi_json_size(orig), 1);
      b_val = dpi_json_get(modified, "b");
      check_int("set: new has b", dpi_json_as_int(b_val), 2);
    end

    // --- Modification: push ---
    begin
      int arr3, arr4, el2;
      arr3 = dpi_json_parse("[1,2]");
      arr4 = dpi_json_push(arr3, dpi_json_parse("3"));
      check_int("push: original size", dpi_json_size(arr3), 2);
      check_int("push: new size", dpi_json_size(arr4), 3);
      el2 = dpi_json_at(arr4, 2);
      check_int("push: new[2]", dpi_json_as_int(el2), 3);
    end

    // --- Modification: insert_at ---
    begin
      int arr5, arr6, ia_el0, ia_el1;
      arr5 = dpi_json_parse("[1,2]");
      arr6 = dpi_json_insert_at(arr5, 0, dpi_json_parse("99"));
      ia_el0 = dpi_json_at(arr6, 0);
      check_int("insert_at: new[0]", dpi_json_as_int(ia_el0), 99);
      ia_el1 = dpi_json_at(arr6, 1);
      check_int("insert_at: new[1]", dpi_json_as_int(ia_el1), 1);
    end

    // --- Modification: remove ---
    begin
      int obj_rem, obj_rem2, b_val;
      obj_rem = dpi_json_parse("{\"a\":1,\"b\":2}");
      obj_rem2 = dpi_json_remove(obj_rem, "a");
      check_bit("remove: original has a", dpi_json_contains(obj_rem, "a"), 1);
      check_bit("remove: new missing a", dpi_json_contains(obj_rem2, "a"), 0);
      b_val = dpi_json_get(obj_rem2, "b");
      check_int("remove: new has b", dpi_json_as_int(b_val), 2);
    end

    // --- Modification: remove_at ---
    begin
      int arr7, arr8, ra_el0, ra_el1;
      arr7 = dpi_json_parse("[10,20,30]");
      arr8 = dpi_json_remove_at(arr7, 1);
      check_int("remove_at: new size", dpi_json_size(arr8), 2);
      ra_el0 = dpi_json_at(arr8, 0);
      check_int("remove_at: new[0]", dpi_json_as_int(ra_el0), 10);
      ra_el1 = dpi_json_at(arr8, 1);
      check_int("remove_at: new[1]", dpi_json_as_int(ra_el1), 30);
    end

    // --- Modification: update ---
    begin
      int u1, u2, u3, a_val, b_val;
      u1 = dpi_json_parse("{\"a\":1}");
      u2 = dpi_json_parse("{\"b\":2,\"a\":99}");
      u3 = dpi_json_update(u1, u2);
      a_val = dpi_json_get(u3, "a");
      check_int("update: overridden a", dpi_json_as_int(a_val), 99);
      b_val = dpi_json_get(u3, "b");
      check_int("update: new b", dpi_json_as_int(b_val), 2);
    end

    // --- JSON Pointer edge cases (RFC 6901: ~0 = ~, ~1 = /) ---
    begin
      int ptr, tilde, slash, nested_slash;
      ptr = dpi_json_parse("{\"~0\":\"tilde\",\"~1\":\"slash\",\"a/b\":{\"c\":1}}");
      tilde = dpi_json_at_path(ptr, "/~00");
      check("pointer: ~0 tilde", dpi_json_as_string(tilde), "tilde");
      slash = dpi_json_at_path(ptr, "/~01");
      check("pointer: ~1 slash", dpi_json_as_string(slash), "slash");
      nested_slash = dpi_json_at_path(ptr, "/a~1b/c");
      check_int("pointer: nested slash key", dpi_json_as_int(nested_slash), 1);
    end

    // --- Destroy ---
    begin
      int tmp = dpi_json_parse("{\"tmp\":1}");
      dpi_json_destroy(tmp);
      check_bit("destroy: no crash", 1, 1);
    end

    // === Complex JSON file tests ===
    begin
      int root_h;
      int c11_project_h, c11_config_h, c11_endpoints_h, c11_ep0_h, c11_authors_h;
      int c11_matrix_h, c11_mixed_h, c11_td_h, c11_deep_h;
      int c11_ep_host_h, c11_deep_val_h, c11_mat_val_h, c11_missing_path_h;

      root_h = dpi_json_parse("sv_json/tests/data/complex.json");
      check_bit("complex: not null", (root_h != 0) ? 1 : 0, 1);
      check_bit("complex: is object", dpi_json_get_type(root_h), 6);
      check_int("complex: root has 4 keys", dpi_json_size(root_h), 4);

      // Navigate nested objects
      c11_project_h = dpi_json_get(root_h, "project");
      check("complex: project.name", dpi_json_as_string(dpi_json_get(c11_project_h, "name")), "sv_serde");
      check("complex: project.version", dpi_json_as_string(dpi_json_get(c11_project_h, "version")), "1.0.0");

      // Nested array access
      c11_authors_h = dpi_json_get(c11_project_h, "authors");
      check_int("complex: authors size", dpi_json_size(c11_authors_h), 3);
      check("complex: authors[0]", dpi_json_as_string(dpi_json_at(c11_authors_h, 0)), "alice");

      // Deep nested: project.config.endpoints[0].host
      c11_config_h = dpi_json_get(c11_project_h, "config");
      c11_endpoints_h = dpi_json_get(c11_config_h, "endpoints");
      c11_ep0_h = dpi_json_at(c11_endpoints_h, 0);
      check("complex: endpoint host", dpi_json_as_string(dpi_json_get(c11_ep0_h, "host")), "10.0.0.1");
      check_int("complex: endpoint port", dpi_json_as_int(dpi_json_get(c11_ep0_h, "port")), 8080);
      check_bit("complex: endpoint tls", dpi_json_as_bool(dpi_json_get(c11_ep0_h, "tls")), 1);

      // Matrix: matrix[1][2] == 6
      c11_matrix_h = dpi_json_get(root_h, "matrix");
      check_int("complex: matrix[1][2]", dpi_json_as_int(dpi_json_at(dpi_json_at(c11_matrix_h, 1), 2)), 6);

      // Mixed array types
      c11_mixed_h = dpi_json_get(root_h, "mixed_array");
      check_int("complex: mixed[0] int", dpi_json_as_int(dpi_json_at(c11_mixed_h, 0)), 1);
      check("complex: mixed[1] string", dpi_json_as_string(dpi_json_at(c11_mixed_h, 1)), "two");
      check_bit("complex: mixed[2] bool", dpi_json_as_bool(dpi_json_at(c11_mixed_h, 2)), 1);
      check_bit("complex: mixed[3] null", dpi_json_get_type(dpi_json_at(c11_mixed_h, 3)), 0);
      check_bit("complex: mixed[4] real", dpi_json_get_type(dpi_json_at(c11_mixed_h, 4)), 3);
      check_bit("complex: mixed[5] object", dpi_json_get_type(dpi_json_at(c11_mixed_h, 5)), 6);
      check_bit("complex: mixed[6] array", dpi_json_get_type(dpi_json_at(c11_mixed_h, 6)), 5);

      // Test data types
      c11_td_h = dpi_json_get(root_h, "test_data");
      check_bit("complex: null_value", dpi_json_get_type(dpi_json_get(c11_td_h, "null_value")), 0);
      check_bit("complex: bool_true", dpi_json_as_bool(dpi_json_get(c11_td_h, "bool_true")), 1);
      check_bit("complex: bool_false", dpi_json_as_bool(dpi_json_get(c11_td_h, "bool_false")), 0);
      check_int("complex: int_zero", dpi_json_as_int(dpi_json_get(c11_td_h, "int_zero")), 0);
      check_int("complex: int_negative", dpi_json_as_int(dpi_json_get(c11_td_h, "int_negative")), -42);
      check("complex: string_empty", dpi_json_as_string(dpi_json_get(c11_td_h, "string_empty")), "");
      check_bit("complex: array_empty", dpi_json_empty(dpi_json_get(c11_td_h, "array_empty")), 1);
      check_bit("complex: object_empty", dpi_json_empty(dpi_json_get(c11_td_h, "object_empty")), 1);

      // Deep nesting
      c11_deep_h = dpi_json_get(dpi_json_get(dpi_json_get(dpi_json_get(dpi_json_get(c11_td_h, "deep_nested"), "l1"), "l2"), "l3"), "l4");
      c11_deep_h = dpi_json_get(c11_deep_h, "l5");
      check("complex: deep value", dpi_json_as_string(dpi_json_get(c11_deep_h, "value")), "deep");

      // Path access
      c11_ep_host_h = dpi_json_at_path(root_h, "/project/config/endpoints/0/host");
      check("complex: at_path endpoint", dpi_json_as_string(c11_ep_host_h), "10.0.0.1");

      c11_deep_val_h = dpi_json_at_path(root_h, "/test_data/deep_nested/l1/l2/l3/l4/l5/value");
      check("complex: at_path deep", dpi_json_as_string(c11_deep_val_h), "deep");

      c11_mat_val_h = dpi_json_at_path(root_h, "/matrix/1/2");
      check_int("complex: at_path matrix", dpi_json_as_int(c11_mat_val_h), 6);

      c11_missing_path_h = dpi_json_at_path(root_h, "/nonexistent/path");
      check_bit("complex: at_path missing null", (c11_missing_path_h == 0) ? 1 : 0, 1);

      // contains on null values
      check_bit("complex: contains null_value", dpi_json_contains(c11_td_h, "null_value"), 1);
    end

    // === Round-trip + edge cases ===
    begin
      int c12_orig_h, c12_dumped_h;
      int c12_data_h, c12_read_back_h;
      int c12_empty_str_h, c12_unicode_h, c12_large_h, c12_neg_h, c12_zero_h;

      // Round-trip: dump then re-parse
      c12_orig_h = dpi_json_parse("{\"a\":1,\"b\":\"hello\",\"c\":[1,2,3]}");
      c12_dumped_h = dpi_json_parse(dpi_json_dump(c12_orig_h, -1));
      check_int("round-trip: a", dpi_json_as_int(dpi_json_get(c12_dumped_h, "a")), 1);
      check("round-trip: b", dpi_json_as_string(dpi_json_get(c12_dumped_h, "b")), "hello");
      check_int("round-trip: c size", dpi_json_size(dpi_json_get(c12_dumped_h, "c")), 3);

      // File dump and re-read
      c12_data_h = dpi_json_parse("{\"x\":100}");
      check_int("dump_file: success", dpi_json_dump_file(c12_data_h, "sv_json/tests/data/out_test.json", 2), 0);
      c12_read_back_h = dpi_json_parse("sv_json/tests/data/out_test.json");
      check_int("dump_file: round-trip", dpi_json_as_int(dpi_json_get(c12_read_back_h, "x")), 100);

      // Edge cases
      c12_empty_str_h = dpi_json_parse("\"\"");
      check("edge: empty string", dpi_json_as_string(c12_empty_str_h), "");

      c12_unicode_h = dpi_json_parse("\"hello \\u4e16\\u754c\"");
      check("edge: unicode", dpi_json_as_string(c12_unicode_h), "hello 世界");

      c12_large_h = dpi_json_parse("2147483647");
      check_int("edge: large int", dpi_json_as_int(c12_large_h), 2147483647);

      c12_neg_h = dpi_json_parse("-42");
      check_int("edge: negative", dpi_json_as_int(c12_neg_h), -42);

      c12_zero_h = dpi_json_parse("0");
      check_int("edge: zero", dpi_json_as_int(c12_zero_h), 0);
    end

    // === New tests: from_string with special characters ===
    begin
      int s1, s2, s3;
      s1 = dpi_json_create_string("say \"hello\"");
      check("from_string: quotes", dpi_json_as_string(s1), "say \"hello\"");

      s2 = dpi_json_create_string("back\\slash");
      check("from_string: backslash", dpi_json_as_string(s2), "back\\slash");

      s3 = dpi_json_create_string("tab\there");
      check("from_string: tab", dpi_json_as_string(s3), "tab\there");
    end

    // === New tests: from_real high precision ===
    begin
      int r1;
      r1 = dpi_json_create_float_val(3.14159265358979);
      check_real("from_real: high precision", dpi_json_as_real(r1), 3.14159265358979);
    end

    // === New tests: as_int/as_real type coercion ===
    begin
      int f_to_i, i_to_f;
      f_to_i = dpi_json_parse("3.0");
      check_int("as_int: float 3.0 -> 3", dpi_json_as_int(f_to_i), 3);

      i_to_f = dpi_json_parse("42");
      check_real("as_real: int 42 -> 42.0", dpi_json_as_real(i_to_f), 42.0);
    end

    // === New tests: type checking via get_type ===
    begin
      int tn, tb, ti, tr, ts, ta, to;
      tn = dpi_json_create_null();
      check_bit("get_type: null", dpi_json_get_type(tn), 0);
      tb = dpi_json_create_bool_val(1);
      check_bit("get_type: bool", dpi_json_get_type(tb), 1);
      ti = dpi_json_create_int_val(10);
      check_bit("get_type: int", dpi_json_get_type(ti), 2);
      tr = dpi_json_create_float_val(1.5);
      check_bit("get_type: real", dpi_json_get_type(tr), 3);
      ts = dpi_json_create_string("abc");
      check_bit("get_type: string", dpi_json_get_type(ts), 4);
      ta = dpi_json_new_array();
      check_bit("get_type: array", dpi_json_get_type(ta), 5);
      to = dpi_json_new_object();
      check_bit("get_type: object", dpi_json_get_type(to), 6);
    end

    // === New tests: clone and is_valid ===
    begin
      int orig, cloned;
      orig = dpi_json_parse("{\"a\":1}");
      cloned = dpi_json_clone(orig);
      check_bit("clone: is_valid", dpi_json_is_valid(cloned), 1);
      check_int("clone: value preserved", dpi_json_as_int(dpi_json_get(cloned, "a")), 1);
      // Modify clone, original should be unchanged
      begin
        int modified;
        modified = dpi_json_set(cloned, "b", dpi_json_parse("2"));
        check_bit("clone: original unchanged", dpi_json_contains(orig, "b"), 0);
        check_int("clone: modified has b", dpi_json_as_int(dpi_json_get(modified, "b")), 2);
      end
    end

    // === New tests: write_file ===
    begin
      int wf_h;
      wf_h = dpi_json_parse("{\"test\":true}");
      check_int("write_file: success", dpi_json_write_file(wf_h, "sv_json/tests/data/out_write.json", 2), 1);
    end

    // === New tests: typed set functions ===
    begin
      int ts_obj, ts_result, ts_val;
      ts_obj = dpi_json_parse("{\"a\":1}");
      ts_result = dpi_json_set_string(ts_obj, "str", "hello");
      ts_val = dpi_json_get(ts_result, "str");
      check("typed_set: string", dpi_json_as_string(ts_val), "hello");

      ts_result = dpi_json_set_int(ts_obj, "num", 42);
      ts_val = dpi_json_get(ts_result, "num");
      check_int("typed_set: int", dpi_json_as_int(ts_val), 42);

      ts_result = dpi_json_set_float(ts_obj, "pi", 3.14);
      ts_val = dpi_json_get(ts_result, "pi");
      check_real("typed_set: float", dpi_json_as_real(ts_val), 3.14);

      ts_result = dpi_json_set_bool(ts_obj, "flag", 1);
      ts_val = dpi_json_get(ts_result, "flag");
      check_bit("typed_set: bool", dpi_json_as_bool(ts_val), 1);

      ts_result = dpi_json_set_null(ts_obj, "empty");
      ts_val = dpi_json_get(ts_result, "empty");
      check_bit("typed_set: null", dpi_json_get_type(ts_val), 0);
    end

    // === Negative tests: malformed input ===
    begin
      int bad_h;
      bad_h = dpi_json_parse("{invalid json}");
      check_bit("malformed: returns null", (bad_h == 0) ? 1 : 0, 1);

      bad_h = dpi_json_parse("");
      check_bit("empty input: returns null", (bad_h == 0) ? 1 : 0, 1);

      bad_h = dpi_json_parse("\"unclosed");
      check_bit("unclosed string: returns null", (bad_h == 0) ? 1 : 0, 1);

      bad_h = dpi_json_parse("[1,2,]");
      check_bit("trailing comma: returns null", (bad_h == 0) ? 1 : 0, 1);
    end

    // === Negative tests: null handle operations ===
    begin
      int null_h = 0;
      check_int("null handle: get_type returns -1", dpi_json_get_type(null_h), -1);
      check("null handle: as_string empty", dpi_json_as_string(null_h), "");
      check_int("null handle: as_int returns 0", dpi_json_as_int(null_h), 0);
      check_real("null handle: as_real returns 0", dpi_json_as_real(null_h), 0.0);
      check_bit("null handle: as_bool returns 0", dpi_json_as_bool(null_h), 0);
      check_bit("null handle: is_valid returns 0", dpi_json_is_valid(null_h), 0);
    end

    // === Negative tests: type mismatch coercion ===
    begin
      int str_h, arr_h, obj_h, null_h2;
      str_h = dpi_json_parse("\"hello\"");
      check_int("mismatch: as_int on string returns 0", dpi_json_as_int(str_h), 0);
      check_real("mismatch: as_real on string returns 0", dpi_json_as_real(str_h), 0.0);
      check_bit("mismatch: as_bool on string returns 0", dpi_json_as_bool(str_h), 0);

      arr_h = dpi_json_parse("[1,2,3]");
      check("mismatch: as_string on array", dpi_json_as_string(arr_h), "");
      check_int("mismatch: as_int on array returns 0", dpi_json_as_int(arr_h), 0);

      obj_h = dpi_json_parse("{\"a\":1}");
      check("mismatch: as_string on object", dpi_json_as_string(obj_h), "");
      check_int("mismatch: as_int on object returns 0", dpi_json_as_int(obj_h), 0);

      null_h2 = dpi_json_create_null();
      check("mismatch: as_string on null", dpi_json_as_string(null_h2), "");
      check_int("mismatch: as_int on null returns 0", dpi_json_as_int(null_h2), 0);
      check_bit("mismatch: as_bool on null returns 0", dpi_json_as_bool(null_h2), 0);
    end

    // === Negative tests: out-of-bounds access ===
    begin
      int arr_h, val_h;
      arr_h = dpi_json_parse("[1,2,3]");
      val_h = dpi_json_at(arr_h, 99);
      check_bit("oob: at(99) returns null", (val_h == 0) ? 1 : 0, 1);
      val_h = dpi_json_at(arr_h, -1);
      check_bit("oob: at(-1) returns null", (val_h == 0) ? 1 : 0, 1);
      val_h = dpi_json_at_path(arr_h, "/nonexistent");
      check_bit("oob: at_path missing on array", (val_h == 0) ? 1 : 0, 1);
    end

    // === Negative tests: operations on wrong container type ===
    begin
      int str_h2, val_h2;
      str_h2 = dpi_json_parse("\"hello\"");
      val_h2 = dpi_json_get(str_h2, "key");
      check_bit("wrong type: get on string returns null", (val_h2 == 0) ? 1 : 0, 1);
      val_h2 = dpi_json_at(str_h2, 0);
      check_bit("wrong type: at on string returns null", (val_h2 == 0) ? 1 : 0, 1);
      check_int("wrong type: size on string returns 0", dpi_json_size(str_h2), 0);
      check_bit("wrong type: empty on non-empty string returns 0", dpi_json_empty(str_h2), 0);
    end

    // === Negative tests: remove non-existent key ===
    begin
      int obj_h2, result_h;
      obj_h2 = dpi_json_parse("{\"a\":1}");
      result_h = dpi_json_remove(obj_h2, "nonexistent");
      check_bit("remove nonexistent: not null", (result_h != 0) ? 1 : 0, 1);
      check_int("remove nonexistent: size unchanged", dpi_json_size(result_h), 1);
    end

    // === Stress tests ===
    begin
      int big_arr, big_obj, deep_h;
      string long_str;

      // Large array
      big_arr = dpi_json_new_array();
      for (int i = 0; i < 100; i++) begin
        big_arr = dpi_json_push(big_arr, dpi_json_create_int_val(i));
      end
      check_int("stress: 100-element array size", dpi_json_size(big_arr), 100);
      check_int("stress: 100-element array[99]", dpi_json_as_int(dpi_json_at(big_arr, 99)), 99);

      // Large object
      big_obj = dpi_json_new_object();
      for (int i = 0; i < 50; i++) begin
        big_obj = dpi_json_set_int(big_obj, $sformatf("key%0d", i), i);
      end
      check_int("stress: 50-key object size", dpi_json_size(big_obj), 50);

      // Deep nesting (10 levels)
      deep_h = dpi_json_parse("{\"l1\":{\"l2\":{\"l3\":{\"l4\":{\"l5\":{\"l6\":{\"l7\":{\"l8\":{\"l9\":{\"l10\":42}}}}}}}}}}");
      check_int("stress: 10-level deep", dpi_json_as_int(dpi_json_at_path(deep_h, "/l1/l2/l3/l4/l5/l6/l7/l8/l9/l10")), 42);

      // Long string
      long_str = "";
      for (int i = 0; i < 100; i++) long_str = {long_str, "abcdefghij"};
      begin
        int ls_h;
        ls_h = dpi_json_create_string(long_str);
        check_int("stress: long string len", dpi_json_as_string(ls_h).len(), 1000);
      end
    end

    $display("\nBasic tests: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count > 0) $finish(1);
    $finish;
  end
endmodule
