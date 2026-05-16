module test_yaml_class;
  import sv_yaml_pkg::*;

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
    sv_yaml y, y2, arr;
    sv_yaml cloned, tagged_value, anchored;
    string s;
    string keys[$];

    $display("=== sv_yaml class tests ===");

    // parse
    y = sv_yaml::parse("name: Alice\nage: 30");
    check_bit("parse not null", (y != null), 1);
    check_bit("parse is object", y.is_object(), 1);
    check_int("parse size", y.size(), 2);

    // get
    check_string("get name", y.get("name").as_string(), "Alice");
    check_int("get age", y.get("age").as_int(), 30);
    check_bit("get missing", (y.get("missing") == null), 1);

    // at_path
    y2 = sv_yaml::parse("x:\n  y: 42");
    check_int("at_path /x/y", y2.at_path("/x/y").as_int(), 42);

    // factory
    y = sv_yaml::from_int(99);
    check_int("from_int", y.as_int(), 99);
    y = sv_yaml::from_string("hello");
    check_string("from_string", y.as_string(), "hello");
    y = sv_yaml::from_bool(1);
    check_bit("from_bool", y.as_bool(), 1);
    y = sv_yaml::make_null();
    check_bit("make_null", y.is_null(), 1);

    // new_object / new_array
    y = sv_yaml::new_object();
    check_bit("new_object", y.is_object(), 1);
    check_bit("new_object empty", y.empty(), 1);
    y = sv_yaml::new_array();
    check_bit("new_array", y.is_array(), 1);

    // set (immutable)
    y = sv_yaml::parse("a: 1");
    y2 = y.set("b", sv_yaml::from_int(2));
    check_bit("set orig unchanged", !y.contains("b"), 1);
    check_int("set new has b", y2.get("b").as_int(), 2);
    check_int("set new size", y2.size(), 2);

    // push (immutable)
    y = sv_yaml::parse("[1, 2]");
    y2 = y.push(sv_yaml::from_int(3));
    check_int("push orig size", y.size(), 2);
    check_int("push new size", y2.size(), 3);
    check_int("push new[2]", y2.at(2).as_int(), 3);

    // remove
    y = sv_yaml::parse("a: 1\nb: 2");
    y2 = y.remove("a");
    check_bit("remove orig has a", y.contains("a"), 1);
    check_bit("remove new missing a", !y2.contains("a"), 1);
    check_int("remove new has b", y2.get("b").as_int(), 2);

    // dump
    y = sv_yaml::parse("x: 1");
    s = y.dump();
    check_bit("dump non-empty", (s.len() > 0) ? 1 : 0, 1);

    // type checks
    y = sv_yaml::parse("s: hi\ni: 1\nr: 3.14\nb: true\nn: null\na: []\no: {}");
    check_bit("is_string", y.get("s").is_string(), 1);
    check_bit("is_int", y.get("i").is_int(), 1);
    check_bit("is_real", y.get("r").is_real(), 1);
    check_bit("is_boolean", y.get("b").is_boolean(), 1);
    check_bit("is_null", y.get("n").is_null(), 1);
    check_bit("is_array", y.get("a").is_array(), 1);
    check_bit("is_object", y.get("o").is_object(), 1);
    check_bit("is_number int", y.get("i").is_number(), 1);
    check_bit("is_number real", y.get("r").is_number(), 1);

    // key_at / get_keys
    y = sv_yaml::parse("a: 1\nb: 2");
    check_string("key_at(0)", y.key_at(0), "a");
    y.get_keys(keys);
    check_int("get_keys size", keys.size(), 2);

    // value_* with defaults
    y = sv_yaml::parse("x: 10");
    check_int("value_int present", y.value_int("x", 0), 10);
    check_int("value_int missing", y.value_int("y", 99), 99);
    check_string("value_string missing", y.value_string("z", "def"), "def");

    // insert_at, remove_at, update
    y = sv_yaml::parse("[1, 2]");
    y2 = y.insert_at(0, sv_yaml::from_int(99));
    check_int("insert_at new[0]", y2.at(0).as_int(), 99);
    check_int("insert_at new[1]", y2.at(1).as_int(), 1);

    y = sv_yaml::parse("[10, 20, 30]");
    y2 = y.remove_at(1);
    check_int("remove_at new size", y2.size(), 2);
    check_int("remove_at new[0]", y2.at(0).as_int(), 10);
    check_int("remove_at new[1]", y2.at(1).as_int(), 30);

    y = sv_yaml::parse("a: 1");
    y2 = y.update(sv_yaml::parse("b: 2\na: 99"));
    check_int("update a overridden", y2.get("a").as_int(), 99);
    check_int("update new b", y2.get("b").as_int(), 2);

    // dump_file
    y = sv_yaml::parse("test: true");
    begin
      int rc;
      rc = y.dump_file("sv_yaml/tests/data/out_vcs_test.yaml");
      check_int("dump_file success", rc, 0);
    end

    // clone
    y = sv_yaml::parse("a: 1");
    begin
      cloned = y.clone();
      check_bit("clone is_valid", cloned.is_valid(), 1);
      check_int("clone value", cloned.get("a").as_int(), 1);
    end

    // from_real
    y = sv_yaml::from_real(3.14);
    check_bit("from_real is_real", y.is_real(), 1);
    // Note: real comparison may have precision issues

    // YAML-specific: yaml_tag, yaml_anchor, yaml_dump_flow
    y = sv_yaml::parse("42");
    begin
      tagged_value = y.yaml_set_tag("!!int");
      check_string("yaml_tag", tagged_value.yaml_tag(), "!!int");
    end

    y = sv_yaml::parse("\"hello\"");
    begin
      anchored = y.yaml_set_anchor("my_anchor");
      check_string("yaml_anchor", anchored.yaml_anchor(), "my_anchor");
    end

    y = sv_yaml::parse("a: 1\nb: 2");
    check_bit("yaml_dump_flow non-empty", (y.yaml_dump_flow().len() > 0) ? 1 : 0, 1);

    // yaml_parse_all
    begin
      sv_yaml docs;
      docs = sv_yaml::yaml_parse_all("---\nname: first\n---\nname: second");
      check_bit("yaml_parse_all not null", (docs != null), 1);
      check_bit("yaml_parse_all is array", docs.is_array(), 1);
      check_int("yaml_parse_all 2 docs", docs.size(), 2);
    end

    // get_type
    y = sv_yaml::parse("{\"s\":\"hi\",\"i\":1,\"r\":3.14,\"b\":true,\"n\":null,\"a\":[],\"o\":{}}");
    check_int("get_type string", y.get("s").get_type(), SV_YAML_STRING);
    check_int("get_type int", y.get("i").get_type(), SV_YAML_INT);
    check_int("get_type real", y.get("r").get_type(), SV_YAML_REAL);
    check_int("get_type bool", y.get("b").get_type(), SV_YAML_BOOLEAN);
    check_int("get_type null", y.get("n").get_type(), SV_YAML_NULL);
    check_int("get_type array", y.get("a").get_type(), SV_YAML_ARRAY);
    check_int("get_type object", y.get("o").get_type(), SV_YAML_OBJECT);

    $display("\n=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
    if (fail_count > 0) $fatal(1, "Tests failed");
    $finish;
  end
endmodule
