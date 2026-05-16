module test_json_class;
  import sv_json_pkg::*;
  int pass_count = 0;
  int fail_count = 0;
`include "serde_test_helpers.sv"
  sv_json j, j2;

  initial begin
    j = sv_json::parse("{\"name\":\"Alice\",\"age\":30}");
    check_bit("parse not null", (j != null), 1);
    check_bit("parse is_object", j.is_object(), 1);
    check_int("parse size", j.size(), 2);
    check_string("get name", j.get("name").as_string(), "Alice");
    check_int("get age", j.get("age").as_int(), 30);
    check_bit("get missing", (j.get("missing") == null), 1);
    // at_path
    j2 = sv_json::parse("{\"x\":{\"y\":42}}");
    check_int("at_path /x/y", j2.at_path("/x/y").as_int(), 42);
    // at_path — root keys
    j = sv_json::parse("{\"name\":\"Alice\",\"age\":30}");
    check_string("at_path /name", j.at_path("/name").as_string(), "Alice");
    check_int("at_path /age", j.at_path("/age").as_int(), 30);
    check_bit("at_path /missing", (j.at_path("/missing") == null), 1);
    // at_path — array index
    j = sv_json::parse("[10, 20, 30]");
    check_int("at_path /0", j.at_path("/0").as_int(), 10);
    check_int("at_path /1", j.at_path("/1").as_int(), 20);
    check_int("at_path /2", j.at_path("/2").as_int(), 30);
    check_bit("at_path /99", (j.at_path("/99") == null), 1);
    // at_path — mixed array + object
    j = sv_json::parse("{\"items\":[{\"name\":\"a\"},{\"name\":\"b\"}]}");
    check_string("at_path /items/0/name", j.at_path("/items/0/name").as_string(), "a");
    check_string("at_path /items/1/name", j.at_path("/items/1/name").as_string(), "b");
    check_bit("at_path /items/0/missing", (j.at_path("/items/0/missing") == null), 1);
    // at_path — object with array child
    j = sv_json::parse("{\"a\":[1,2,3]}");
    check_int("at_path /a/0", j.at_path("/a/0").as_int(), 1);
    check_int("at_path /a/2", j.at_path("/a/2").as_int(), 3);
    // at_path — deep nesting
    j = sv_json::parse("{\"a\":{\"b\":{\"c\":{\"d\":42}}}}");
    check_int("at_path /a/b/c/d", j.at_path("/a/b/c/d").as_int(), 42);
    j = sv_json::from_int(99);
    check_int("from_int", j.as_int(), 99);
    j = sv_json::from_string("hello");
    check_string("from_string", j.as_string(), "hello");
    j = sv_json::from_bool(1);
    check_bit("from_bool", j.as_bool(), 1);
    j = sv_json::make_null();
    check_bit("make_null is_null", j.is_null(), 1);
    j = sv_json::new_object();
    check_bit("new_object", j.is_object(), 1);
    check_bit("new_object empty", j.empty(), 1);
    j = sv_json::new_array();
    check_bit("new_array", j.is_array(), 1);
    j = sv_json::parse("{\"a\":1}");
    j2 = j.set("b", sv_json::from_int(2));
    check_bit("set orig unchanged", !j.contains("b"), 1);
    check_int("set new has b", j2.get("b").as_int(), 2);
    j = sv_json::parse("[1,2]");
    j2 = j.push(sv_json::from_int(3));
    check_int("push orig size", j.size(), 2);
    check_int("push new size", j2.size(), 3);
    check_int("push new[2]", j2.at(2).as_int(), 3);
    j = sv_json::parse("{\"a\":1,\"b\":2}");
    j2 = j.remove("a");
    check_bit("remove orig has a", j.contains("a"), 1);
    check_bit("remove new missing a", !j2.contains("a"), 1);
    j = sv_json::parse("[1,2]");
    j2 = j.insert_at(0, sv_json::from_int(99));
    check_int("insert_at new[0]", j2.at(0).as_int(), 99);
    check_int("insert_at new[1]", j2.at(1).as_int(), 1);
    j = sv_json::parse("[10,20,30]");
    j2 = j.remove_at(1);
    check_int("remove_at new size", j2.size(), 2);
    check_int("remove_at new[0]", j2.at(0).as_int(), 10);
    j = sv_json::parse("{\"a\":1}");
    j2 = j.update(sv_json::parse("{\"b\":2,\"a\":99}"));
    check_int("update a", j2.get("a").as_int(), 99);
    check_int("update b", j2.get("b").as_int(), 2);
    j = sv_json::parse("{\"x\":1}");
    check_bit("dump non-empty", (j.dump().len() > 0) ? 1 : 0, 1);
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
    j = sv_json::parse("{\"a\":1,\"b\":2}");
    begin
      string keys[$];
      j.get_keys(keys);
      check_int("get_keys size", keys.size(), 2);
    end
    j = sv_json::parse("{\"x\":10}");
    check_int("value_int present", j.value_int("x", 0), 10);
    check_int("value_int missing", j.value_int("y", 99), 99);
    check_string("value_string missing", j.value_string("z", "def"), "def");
    j = sv_json::parse("{\"s\":\"hi\",\"i\":1,\"r\":3.14,\"b\":true,\"n\":null,\"a\":[],\"o\":{}}");
    check_int("get_type string", j.get("s").get_type(), SV_JSON_STRING);
    check_int("get_type int", j.get("i").get_type(), SV_JSON_INT);
    check_int("get_type real", j.get("r").get_type(), SV_JSON_REAL);
    check_int("get_type bool", j.get("b").get_type(), SV_JSON_BOOLEAN);
    check_int("get_type null", j.get("n").get_type(), SV_JSON_NULL);
    check_int("get_type array", j.get("a").get_type(), SV_JSON_ARRAY);
    check_int("get_type object", j.get("o").get_type(), SV_JSON_OBJECT);
    j = sv_json::parse("{\"a\":1}");
    j2 = j.clone();
    check_bit("clone is_valid", j2.is_valid(), 1);
    check_int("clone value", j2.get("a").as_int(), 1);
    j = sv_json::parse("{\"test\":true}");
    check_int("dump_file", j.dump_file("sv_json/tests/data/out_class_test.json"), 0);
    $display("\n=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
    if (fail_count > 0) $fatal(1, "Tests failed");
    $finish;
  end
endmodule
