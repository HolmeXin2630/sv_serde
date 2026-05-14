module sv_json_test;
  int pass_count = 0;
  int fail_count = 0;

  // DPI imports — lifecycle
  import "DPI-C" function int    dpi_json_new_object();
  import "DPI-C" function int    dpi_json_new_array();
  import "DPI-C" function int    dpi_json_parse(input string input_str);

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

  // DPI imports — serialization
  import "DPI-C" function string dpi_json_dump(input int h, input int indent);

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

    $display("\nBasic tests: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count > 0) $finish(1);
    $finish;
  end
endmodule
