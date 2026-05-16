module vcs_json_test;
  import sv_json_pkg::*;

  int pass_count = 0;
  int fail_count = 0;

  task check_int(string name, int actual, int expected);
    if (actual === expected) begin
      $display("[PASS] %s: got %0d", name, actual);
      pass_count++;
    end else begin
      $display("[FAIL] %s: expected %0d, got %0d", name, expected, actual);
      fail_count++;
    end
  endtask

  task check_string(string name, string actual, string expected);
    if (actual == expected) begin
      $display("[PASS] %s: got '%s'", name, actual);
      pass_count++;
    end else begin
      $display("[FAIL] %s: expected '%s', got '%s'", name, expected, actual);
      fail_count++;
    end
  endtask

  task check_bit(string name, bit actual, bit expected);
    if (actual === expected) begin
      $display("[PASS] %s: got %0d", name, actual);
      pass_count++;
    end else begin
      $display("[FAIL] %s: expected %0d, got %0d", name, expected, actual);
      fail_count++;
    end
  endtask

  initial begin
    sv_json j, j2, arr;
    string s;
    int v;

    $display("=== VCS sv_json class tests ===");

    // parse
    j = sv_json::parse("{\"name\":\"Alice\",\"age\":30}");
    check_bit("parse not null", (j != null), 1);
    check_bit("parse is object", j.is_object(), 1);
    check_int("parse size", j.size(), 2);

    // get
    check_string("get name", j.get("name").as_string(), "Alice");
    check_int("get age", j.get("age").as_int(), 30);
    check_bit("get missing", (j.get("missing") == null), 1);

    // at_path
    j2 = sv_json::parse("{\"x\":{\"y\":42}}");
    check_int("at_path /x/y", j2.at_path("/x/y").as_int(), 42);

    // factory
    j = sv_json::from_int(99);
    check_int("from_int", j.as_int(), 99);
    j = sv_json::from_string("hello");
    check_string("from_string", j.as_string(), "hello");
    j = sv_json::from_bool(1);
    check_bit("from_bool", j.as_bool(), 1);
    j = sv_json::make_null();
    check_bit("make_null", j.is_null(), 1);

    // new_object / new_array
    j = sv_json::new_object();
    check_bit("new_object", j.is_object(), 1);
    check_bit("new_object empty", j.empty(), 1);
    j = sv_json::new_array();
    check_bit("new_array", j.is_array(), 1);

    // set (immutable)
    j = sv_json::parse("{\"a\":1}");
    j2 = j.set("b", sv_json::from_int(2));
    check_bit("set orig unchanged", !j.contains("b"), 1);
    check_int("set new has b", j2.get("b").as_int(), 2);
    check_int("set new size", j2.size(), 2);

    // push (immutable)
    j = sv_json::parse("[1,2]");
    j2 = j.push(sv_json::from_int(3));
    check_int("push orig size", j.size(), 2);
    check_int("push new size", j2.size(), 3);
    check_int("push new[2]", j2.at(2).as_int(), 3);

    // remove
    j = sv_json::parse("{\"a\":1,\"b\":2}");
    j2 = j.remove("a");
    check_bit("remove orig has a", j.contains("a"), 1);
    check_bit("remove new missing a", !j2.contains("a"), 1);
    check_int("remove new has b", j2.get("b").as_int(), 2);

    // dump
    j = sv_json::parse("{\"x\":1}");
    s = j.dump();
    check_bit("dump non-empty", (s.len() > 0) ? 1 : 0, 1);

    // type checks
    j = sv_json::parse("{\"s\":\"hi\",\"i\":1,\"r\":3.14,\"b\":true,\"n\":null,\"a\":[],\"o\":{}}");
    check_bit("is_string", j.get("s").is_string(), 1);
    check_bit("is_int", j.get("i").is_int(), 1);
    check_bit("is_real", j.get("r").is_real(), 1);
    check_bit("is_boolean", j.get("b").is_boolean(), 1);
    check_bit("is_null", j.get("n").is_null(), 1);
    check_bit("is_array", j.get("a").is_array(), 1);
    check_bit("is_object", j.get("o").is_object(), 1);
    check_bit("is_number int", j.get("i").is_number(), 1);
    check_bit("is_number real", j.get("r").is_number(), 1);

    // key_at / get_keys
    j = sv_json::parse("{\"a\":1,\"b\":2}");
    check_string("key_at(0)", j.key_at(0), "a");
    string keys[$];
    j.get_keys(keys);
    check_int("get_keys size", keys.size(), 2);

    // value_* with defaults
    j = sv_json::parse("{\"x\":10}");
    check_int("value_int present", j.value_int("x", 0), 10);
    check_int("value_int missing", j.value_int("y", 99), 99);
    check_string("value_string missing", j.value_string("z", "def"), "def");

    $display("\n=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
    if (fail_count > 0) $fatal(1, "Tests failed");
    $finish;
  end
endmodule
