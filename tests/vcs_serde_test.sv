module vcs_serde_test;
  import sv_serde_pkg::*;

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
    sv_json j;
    sv_yaml y;

    $display("=== VCS sv_serde unified import test ===");

    // JSON via sv_serde_pkg
    j = sv_json::parse("{\"key\":\"json_val\"}");
    check_bit("json: not null", (j != null), 1);
    check_string("json: get", j.get("key").as_string(), "json_val");

    // YAML via sv_serde_pkg
    y = sv_yaml::parse("key: yaml_val");
    check_bit("yaml: not null", (y != null), 1);
    check_string("yaml: get", y.get("key").as_string(), "yaml_val");

    // Both types available simultaneously
    j = sv_json::new_object();
    y = sv_yaml::new_object();
    check_bit("json: new_object", j.is_object(), 1);
    check_bit("yaml: new_object", y.is_object(), 1);

    // Cross-format round-trip
    j = sv_json::parse("{\"name\":\"test\",\"value\":42}");
    y = sv_yaml::parse("name: test\nvalue: 42");
    check_string("cross: json name", j.get("name").as_string(), "test");
    check_string("cross: yaml name", y.get("name").as_string(), "test");
    check_int("cross: json value", j.get("value").as_int(), 42);
    check_int("cross: yaml value", y.get("value").as_int(), 42);

    $display("\n=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
    if (fail_count > 0) $fatal(1, "Tests failed");
    $finish;
  end
endmodule
