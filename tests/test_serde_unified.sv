// Test sv_serde_pkg unified import
module test_serde_unified;
  import sv_serde_pkg::*;
  import sv_json_pkg::sv_json;
  import sv_yaml_pkg::sv_yaml;
  int pass_count = 0;
  int fail_count = 0;
`include "serde_test_helpers.sv"

  initial begin
    sv_json j;
    sv_yaml y;
    sv_serde_type_e t;

    $display("=== sv_serde_pkg unified import tests ===");

    // Verify type enum works
    t = SERDE_STRING;
    check_int("SERDE_STRING", t, SERDE_STRING);
    check_int("SERDE_STRING value", SERDE_STRING, 4);

    // Verify backward-compatible JSON constants
    check_int("SV_JSON_STRING", SV_JSON_STRING, SERDE_STRING);
    check_int("SV_JSON_INT", SV_JSON_INT, SERDE_INT);
    check_int("SV_JSON_REAL", SV_JSON_REAL, SERDE_REAL);
    check_int("SV_JSON_BOOLEAN", SV_JSON_BOOLEAN, SERDE_BOOL);
    check_int("SV_JSON_NULL", SV_JSON_NULL, SERDE_NULL);
    check_int("SV_JSON_ARRAY", SV_JSON_ARRAY, SERDE_ARRAY);
    check_int("SV_JSON_OBJECT", SV_JSON_OBJECT, SERDE_OBJECT);

    // Verify backward-compatible YAML constants
    check_int("SV_YAML_STRING", SV_YAML_STRING, SERDE_STRING);
    check_int("SV_YAML_INT", SV_YAML_INT, SERDE_INT);
    check_int("SV_YAML_REAL", SV_YAML_REAL, SERDE_REAL);
    check_int("SV_YAML_BOOLEAN", SV_YAML_BOOLEAN, SERDE_BOOL);
    check_int("SV_YAML_NULL", SV_YAML_NULL, SERDE_NULL);
    check_int("SV_YAML_ARRAY", SV_YAML_ARRAY, SERDE_ARRAY);
    check_int("SV_YAML_OBJECT", SV_YAML_OBJECT, SERDE_OBJECT);

    // Use sv_json via unified import
    j = sv_json::parse("{\"name\":\"Alice\",\"age\":30}");
    check_bit("json parse", (j != null), 1);
    check_bit("json is_object", j.is_object(), 1);
    check_string("json get", j.get("name").as_string(), "Alice");
    check_int("json get_type", j.get("name").get_type(), SERDE_STRING);

    // Use sv_yaml via unified import
    y = sv_yaml::parse("name: Bob\nage: 25");
    check_bit("yaml parse", (y != null), 1);
    check_bit("yaml is_object", y.is_object(), 1);
    check_string("yaml get", y.get("name").as_string(), "Bob");
    check_int("yaml get_type", y.get("name").get_type(), SERDE_STRING);

    // Both types accessible from same package
    check_bit("json and yaml both work", (j != null && y != null), 1);

    $display("\n=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
    if (fail_count > 0) $fatal(1, "Tests failed");
    $finish;
  end
endmodule
