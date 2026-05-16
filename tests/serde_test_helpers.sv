// Shared test helper tasks for sv_json and sv_yaml test suites.
// Include via: `include "serde_test_helpers.sv"
// Requires module-level variables: pass_count, fail_count

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
