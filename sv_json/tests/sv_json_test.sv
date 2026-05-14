module sv_json_test;
  int pass_count = 0;
  int fail_count = 0;

  // DPI imports — lifecycle
  import "DPI-C" function int    dpi_json_new_object();
  import "DPI-C" function int    dpi_json_new_array();
  import "DPI-C" function int    dpi_json_parse(input string input_str);
  import "DPI-C" function void   dpi_json_destroy(input int h);

  // DPI imports — type checking
  import "DPI-C" function int    dpi_json_is_null(input int h);
  import "DPI-C" function int    dpi_json_is_boolean(input int h);
  import "DPI-C" function int    dpi_json_is_int(input int h);
  import "DPI-C" function int    dpi_json_is_string(input int h);
  import "DPI-C" function int    dpi_json_is_array(input int h);
  import "DPI-C" function int    dpi_json_is_object(input int h);

  // DPI imports — value extraction
  import "DPI-C" function string dpi_json_as_string(input int h);
  import "DPI-C" function int    dpi_json_as_int(input int h);
  import "DPI-C" function real   dpi_json_as_real(input int h);
  import "DPI-C" function int    dpi_json_as_bool(input int h);

  // DPI imports — structure access
  import "DPI-C" function int    dpi_json_get(input int h, input string key);
  import "DPI-C" function int    dpi_json_at(input int h, input int idx);
  import "DPI-C" function int    dpi_json_empty(input int h);
  import "DPI-C" function int    dpi_json_size(input int h);

  // DPI imports — structure access (extended)
  import "DPI-C" function int    dpi_json_is_real(input int h);
  import "DPI-C" function int    dpi_json_at_path(input int h, input string path);
  import "DPI-C" function int    dpi_json_contains(input int h, input string key);
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

  task automatic check(string test_name, string actual, string expected);
    if (actual == expected) begin
      $display("[PASS] %s: got '%s'", test_name, actual);
      pass_count++;
    end else begin
      $display("[FAIL] %s: expected '%s', got '%s'", test_name, expected, actual);
      fail_count++;
    end
  endtask

  task automatic check_int(string test_name, int actual, int expected);
    if (actual == expected) begin
      $display("[PASS] %s: got %0d", test_name, actual);
      pass_count++;
    end else begin
      $display("[FAIL] %s: expected %0d, got %0d", test_name, expected, actual);
      fail_count++;
    end
  endtask

  task automatic check_bit(string test_name, int actual, int expected);
    if (actual == expected) begin
      $display("[PASS] %s: got %0d", test_name, actual);
      pass_count++;
    end else begin
      $display("[FAIL] %s: expected %0d, got %0d", test_name, expected, actual);
      fail_count++;
    end
  endtask

  task automatic check_real(string test_name, real actual, real expected);
    if (actual == expected) begin
      $display("[PASS] %s: got %f", test_name, actual);
      pass_count++;
    end else begin
      $display("[FAIL] %s: expected %f, got %f", test_name, expected, actual);
      fail_count++;
    end
  endtask

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
    check_bit("parse: is object", dpi_json_is_object(j), 1);
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
    check_bit("is_object on object", dpi_json_is_object(j), 1);

    h = dpi_json_get(j, "name");
    check_bit("is_string on string", dpi_json_is_string(h), 1);

    h = dpi_json_get(j, "age");
    check_bit("is_int on int", dpi_json_is_int(h), 1);

    // --- from_int, from_real, from_bool, from_string, make_null ---
    h = dpi_json_parse("42");
    check_int("from_int", dpi_json_as_int(h), 42);

    h = dpi_json_parse("3.14");
    check_real("from_real", dpi_json_as_real(h), 3.14);

    h = dpi_json_parse("true");
    check_bit("from_bool true", dpi_json_as_bool(h), 1);

    h = dpi_json_parse("\"hello\"");
    check("from_string", dpi_json_as_string(h), "hello");

    h = dpi_json_parse("null");
    check_bit("make_null is_null", dpi_json_is_null(h), 1);

    // --- new_object, new_array ---
    h = dpi_json_new_object();
    check_bit("new_object is_object", dpi_json_is_object(h), 1);
    check_bit("new_object empty", dpi_json_empty(h), 1);

    h = dpi_json_new_array();
    check_bit("new_array is_array", dpi_json_is_array(h), 1);
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

    $display("\nBasic tests: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count > 0) $finish(1);
    $finish;
  end
endmodule
