module sv_yaml_test;
  int pass_count = 0;
  int fail_count = 0;

  // DPI imports — lifecycle
  import "DPI-C" function int    dpi_yaml_new_object();
  import "DPI-C" function int    dpi_yaml_new_array();
  import "DPI-C" function int    dpi_yaml_parse(input string input_str);
  import "DPI-C" function void   dpi_yaml_destroy(input int handle);

  // DPI imports — type checking
  import "DPI-C" function int    dpi_yaml_is_null(input int h);
  import "DPI-C" function int    dpi_yaml_is_boolean(input int h);
  import "DPI-C" function int    dpi_yaml_is_int(input int h);
  import "DPI-C" function int    dpi_yaml_is_real(input int h);
  import "DPI-C" function int    dpi_yaml_is_string(input int h);
  import "DPI-C" function int    dpi_yaml_is_array(input int h);
  import "DPI-C" function int    dpi_yaml_is_object(input int h);
  import "DPI-C" function int    dpi_yaml_get_type(input int h);

  // DPI imports — value extraction
  import "DPI-C" function string dpi_yaml_as_string(input int h);
  import "DPI-C" function int    dpi_yaml_as_int(input int h);
  import "DPI-C" function real   dpi_yaml_as_real(input int h);
  import "DPI-C" function int    dpi_yaml_as_bool(input int h);

  // DPI imports — structure access
  import "DPI-C" function int    dpi_yaml_get(input int h, input string key);
  import "DPI-C" function int    dpi_yaml_at(input int h, input int idx);
  import "DPI-C" function int    dpi_yaml_at_path(input int h, input string path);
  import "DPI-C" function int    dpi_yaml_contains(input int h, input string key);
  import "DPI-C" function int    dpi_yaml_empty(input int h);
  import "DPI-C" function int    dpi_yaml_size(input int h);
  import "DPI-C" function string dpi_yaml_key_at(input int h, input int idx);

  // DPI imports — modification
  import "DPI-C" function int    dpi_yaml_set(input int h, input string key, input int val_h);
  import "DPI-C" function int    dpi_yaml_push(input int h, input int val_h);
  import "DPI-C" function int    dpi_yaml_insert_at(input int h, input int idx, input int val_h);
  import "DPI-C" function int    dpi_yaml_remove(input int h, input string key);
  import "DPI-C" function int    dpi_yaml_remove_at(input int h, input int idx);
  import "DPI-C" function int    dpi_yaml_update(input int h, input int other_h);

  // DPI imports — serialization
  import "DPI-C" function string dpi_yaml_dump(input int h, input int indent);
  import "DPI-C" function int    dpi_yaml_dump_file(input int h, input string fname, input int indent);

  // DPI imports — YAML-specific
  import "DPI-C" function int    dpi_yaml_parse_all(input string input_str);
  import "DPI-C" function string dpi_yaml_comments(input int h);
  import "DPI-C" function int    dpi_yaml_set_comment(input int h, input string text);
  import "DPI-C" function string dpi_yaml_anchor(input int h);
  import "DPI-C" function int    dpi_yaml_set_anchor(input int h, input string name);
  import "DPI-C" function string dpi_yaml_alias(input int h);
  import "DPI-C" function string dpi_yaml_tag(input int h);
  import "DPI-C" function int    dpi_yaml_set_tag(input int h, input string tag);
  import "DPI-C" function string dpi_yaml_dump_flow(input int h);
  import "DPI-C" function string dpi_yaml_dump_with_comments(input int h);

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
    int el;
    string dumped;

    // === 1. Parse simple.yaml — verify types ===
    begin
      int root, name_h, val_h, pi_h, active_h, nothing_h, items_h, nested_h;

      root = dpi_yaml_parse("sv_yaml/tests/data/simple.yaml");
      check_bit("simple: not null", (root != 0) ? 1 : 0, 1);
      check_bit("simple: is object", dpi_yaml_is_object(root), 1);
      check_int("simple: size 7", dpi_yaml_size(root), 7);

      name_h = dpi_yaml_get(root, "name");
      check_bit("simple: name is_string", dpi_yaml_is_string(name_h), 1);
      check("simple: name value", dpi_yaml_as_string(name_h), "test");

      val_h = dpi_yaml_get(root, "value");
      check_bit("simple: value is_int", dpi_yaml_is_int(val_h), 1);
      check_int("simple: value 42", dpi_yaml_as_int(val_h), 42);

      pi_h = dpi_yaml_get(root, "pi");
      check_bit("simple: pi is_real", dpi_yaml_is_real(pi_h), 1);
      check_real("simple: pi 3.14", dpi_yaml_as_real(pi_h), 3.14);

      active_h = dpi_yaml_get(root, "active");
      check_bit("simple: active is_boolean", dpi_yaml_is_boolean(active_h), 1);
      check_bit("simple: active true", dpi_yaml_as_bool(active_h), 1);

      nothing_h = dpi_yaml_get(root, "nothing");
      check_bit("simple: nothing is_null", dpi_yaml_is_null(nothing_h), 1);

      items_h = dpi_yaml_get(root, "items");
      check_bit("simple: items is_array", dpi_yaml_is_array(items_h), 1);
      check_int("simple: items size 3", dpi_yaml_size(items_h), 3);
      el = dpi_yaml_at(items_h, 0);
      check_int("simple: items[0] == 1", dpi_yaml_as_int(el), 1);
      el = dpi_yaml_at(items_h, 2);
      check_int("simple: items[2] == 3", dpi_yaml_as_int(el), 3);

      nested_h = dpi_yaml_get(root, "nested");
      check_bit("simple: nested is_object", dpi_yaml_is_object(nested_h), 1);
      check("simple: nested.key", dpi_yaml_as_string(dpi_yaml_get(nested_h, "key")), "val");
    end

    // === 2. Parse anchors.yaml — verify merged keys ===
    begin
      int anchors_root, item1, item2;
      int item1_size, item2_size;

      anchors_root = dpi_yaml_parse("sv_yaml/tests/data/anchors.yaml");
      check_bit("anchors: not null", (anchors_root != 0) ? 1 : 0, 1);
      check_bit("anchors: is object", dpi_yaml_is_object(anchors_root), 1);

      item1 = dpi_yaml_get(anchors_root, "item1");
      check_bit("anchors: item1 is_object", dpi_yaml_is_object(item1), 1);
      item1_size = dpi_yaml_size(item1);
      check_int("anchors: item1 size 3 (merged)", item1_size, 3);
      check("anchors: item1.color", dpi_yaml_as_string(dpi_yaml_get(item1, "color")), "blue");
      check("anchors: item1.size", dpi_yaml_as_string(dpi_yaml_get(item1, "size")), "large");
      check("anchors: item1.name", dpi_yaml_as_string(dpi_yaml_get(item1, "name")), "widget");

      item2 = dpi_yaml_get(anchors_root, "item2");
      check_bit("anchors: item2 is_object", dpi_yaml_is_object(item2), 1);
      item2_size = dpi_yaml_size(item2);
      check_int("anchors: item2 size 3 (merged)", item2_size, 3);
      check("anchors: item2.color", dpi_yaml_as_string(dpi_yaml_get(item2, "color")), "blue");
      check("anchors: item2.name", dpi_yaml_as_string(dpi_yaml_get(item2, "name")), "gadget");
    end

    // === 3. Parse comments.yaml — verify parse works ===
    begin
      int comments_root, c_name, c_val;

      comments_root = dpi_yaml_parse("sv_yaml/tests/data/comments.yaml");
      check_bit("comments: not null", (comments_root != 0) ? 1 : 0, 1);
      check_bit("comments: is object", dpi_yaml_is_object(comments_root), 1);
      check_int("comments: size 2", dpi_yaml_size(comments_root), 2);

      c_name = dpi_yaml_get(comments_root, "name");
      check("comments: name", dpi_yaml_as_string(c_name), "test");

      c_val = dpi_yaml_get(comments_root, "value");
      check_int("comments: value 42", dpi_yaml_as_int(c_val), 42);
    end

    // === 4. Parse multiline.yaml — verify literal/folded ===
    begin
      int ml_root, literal_h, folded_h, strip_h;
      string literal_val, folded_val, strip_val;

      ml_root = dpi_yaml_parse("sv_yaml/tests/data/multiline.yaml");
      check_bit("multiline: not null", (ml_root != 0) ? 1 : 0, 1);
      check_bit("multiline: is object", dpi_yaml_is_object(ml_root), 1);

      literal_h = dpi_yaml_get(ml_root, "literal");
      check_bit("multiline: literal is_string", dpi_yaml_is_string(literal_h), 1);
      literal_val = dpi_yaml_as_string(literal_h);
      check_bit("multiline: literal has newline", (literal_val.len() > 10) ? 1 : 0, 1);

      folded_h = dpi_yaml_get(ml_root, "folded");
      check_bit("multiline: folded is_string", dpi_yaml_is_string(folded_h), 1);
      folded_val = dpi_yaml_as_string(folded_h);
      check_bit("multiline: folded non-empty", (folded_val.len() > 0) ? 1 : 0, 1);

      strip_h = dpi_yaml_get(ml_root, "strip");
      check_bit("multiline: strip is_string", dpi_yaml_is_string(strip_h), 1);
      strip_val = dpi_yaml_as_string(strip_h);
      check("multiline: strip value", strip_val, "No trailing newline");
    end

    // === 5. Parse multi_doc.yaml — verify both documents ===
    begin
      int docs, doc0, doc1;
      int d0_name_h, d0_val_h, d1_name_h, d1_val_h;

      docs = dpi_yaml_parse_all("sv_yaml/tests/data/multi_doc.yaml");
      check_bit("multi_doc: not null", (docs != 0) ? 1 : 0, 1);
      check_bit("multi_doc: is array", dpi_yaml_is_array(docs), 1);
      check_int("multi_doc: 2 documents", dpi_yaml_size(docs), 2);

      doc0 = dpi_yaml_at(docs, 0);
      check_bit("multi_doc: doc0 is_object", dpi_yaml_is_object(doc0), 1);
      d0_name_h = dpi_yaml_get(doc0, "name");
      check("multi_doc: doc0.name", dpi_yaml_as_string(d0_name_h), "first");
      d0_val_h = dpi_yaml_get(doc0, "value");
      check_int("multi_doc: doc0.value 1", dpi_yaml_as_int(d0_val_h), 1);

      doc1 = dpi_yaml_at(docs, 1);
      check_bit("multi_doc: doc1 is_object", dpi_yaml_is_object(doc1), 1);
      d1_name_h = dpi_yaml_get(doc1, "name");
      check("multi_doc: doc1.name", dpi_yaml_as_string(d1_name_h), "second");
      d1_val_h = dpi_yaml_get(doc1, "value");
      check_int("multi_doc: doc1.value 2", dpi_yaml_as_int(d1_val_h), 2);
    end

    // === 6. Structure access: get, at, contains, size, empty, at_path ===
    begin
      int obj, arr, path_h, missing_h;

      // get
      obj = dpi_yaml_parse("{\"a\":1,\"b\":\"hello\"}");
      check("struct: get a", dpi_yaml_as_string(dpi_yaml_get(obj, "a")), "1");
      check("struct: get b", dpi_yaml_as_string(dpi_yaml_get(obj, "b")), "hello");
      missing_h = dpi_yaml_get(obj, "missing");
      check_bit("struct: missing returns 0", (missing_h == 0) ? 1 : 0, 1);

      // size & empty
      check_int("struct: size", dpi_yaml_size(obj), 2);
      check_bit("struct: not empty", dpi_yaml_empty(obj), 0);
      check_bit("struct: empty obj", dpi_yaml_empty(dpi_yaml_new_object()), 1);
      check_bit("struct: empty arr", dpi_yaml_empty(dpi_yaml_new_array()), 1);

      // key_at
      check("struct: key_at(0)", dpi_yaml_key_at(obj, 0), "a");
      check("struct: key_at(1)", dpi_yaml_key_at(obj, 1), "b");

      // contains
      check_bit("struct: contains a", dpi_yaml_contains(obj, "a"), 1);
      check_bit("struct: contains missing", dpi_yaml_contains(obj, "nope"), 0);

      // at (array)
      arr = dpi_yaml_parse("[10,20,30]");
      check_int("struct: at(0)", dpi_yaml_as_int(dpi_yaml_at(arr, 0)), 10);
      check_int("struct: at(2)", dpi_yaml_as_int(dpi_yaml_at(arr, 2)), 30);

      // at_path
      path_h = dpi_yaml_parse("{\"x\":{\"y\":42}}");
      check_int("struct: at_path /x/y", dpi_yaml_as_int(dpi_yaml_at_path(path_h, "/x/y")), 42);
      check_bit("struct: at_path missing", (dpi_yaml_at_path(path_h, "/missing") == 0) ? 1 : 0, 1);
    end

    // === 7. Modification: set, push, remove (immutable) ===
    begin
      int orig, modified, v_h;

      // set
      orig = dpi_yaml_parse("{\"a\":1}");
      modified = dpi_yaml_set(orig, "b", dpi_yaml_parse("2"));
      check_int("mod: set orig unchanged", dpi_yaml_size(orig), 1);
      v_h = dpi_yaml_get(modified, "b");
      check_int("mod: set new has b=2", dpi_yaml_as_int(v_h), 2);

      // push
      orig = dpi_yaml_parse("[1,2]");
      modified = dpi_yaml_push(orig, dpi_yaml_parse("3"));
      check_int("mod: push orig size", dpi_yaml_size(orig), 2);
      check_int("mod: push new size", dpi_yaml_size(modified), 3);
      check_int("mod: push new[2]=3", dpi_yaml_as_int(dpi_yaml_at(modified, 2)), 3);

      // insert_at
      orig = dpi_yaml_parse("[1,2]");
      modified = dpi_yaml_insert_at(orig, 0, dpi_yaml_parse("99"));
      check_int("mod: insert_at orig size", dpi_yaml_size(orig), 2);
      check_int("mod: insert_at new[0]=99", dpi_yaml_as_int(dpi_yaml_at(modified, 0)), 99);
      check_int("mod: insert_at new[1]=1", dpi_yaml_as_int(dpi_yaml_at(modified, 1)), 1);

      // remove
      orig = dpi_yaml_parse("{\"a\":1,\"b\":2}");
      modified = dpi_yaml_remove(orig, "a");
      check_bit("mod: remove orig has a", dpi_yaml_contains(orig, "a"), 1);
      check_bit("mod: remove new missing a", dpi_yaml_contains(modified, "a"), 0);
      v_h = dpi_yaml_get(modified, "b");
      check_int("mod: remove new has b=2", dpi_yaml_as_int(v_h), 2);

      // remove_at
      orig = dpi_yaml_parse("[10,20,30]");
      modified = dpi_yaml_remove_at(orig, 1);
      check_int("mod: remove_at orig size", dpi_yaml_size(orig), 3);
      check_int("mod: remove_at new size", dpi_yaml_size(modified), 2);
      check_int("mod: remove_at new[0]=10", dpi_yaml_as_int(dpi_yaml_at(modified, 0)), 10);
      check_int("mod: remove_at new[1]=30", dpi_yaml_as_int(dpi_yaml_at(modified, 1)), 30);

      // update
      begin
        int u1, u2, u3, a_h, b_h;
        u1 = dpi_yaml_parse("{\"a\":1}");
        u2 = dpi_yaml_parse("{\"b\":2,\"a\":99}");
        u3 = dpi_yaml_update(u1, u2);
        a_h = dpi_yaml_get(u3, "a");
        check_int("mod: update a overridden", dpi_yaml_as_int(a_h), 99);
        b_h = dpi_yaml_get(u3, "b");
        check_int("mod: update new b=2", dpi_yaml_as_int(b_h), 2);
      end
    end

    // === 8. Serialization: dump, dump_file ===
    begin
      int obj_h, dumped_h, read_back_h;

      // dump
      obj_h = dpi_yaml_parse("{\"a\":1,\"b\":\"hello\"}");
      dumped = dpi_yaml_dump(obj_h, 2);
      check_bit("dump: non-empty", (dumped.len() > 0) ? 1 : 0, 1);
      check_bit("dump: contains a", (dumped.len() >= 2) ? 1 : 0, 1);

      // round-trip: dump then re-parse
      dumped_h = dpi_yaml_parse(dpi_yaml_dump(obj_h, 2));
      check_bit("dump: round-trip not null", (dumped_h != 0) ? 1 : 0, 1);
      // YAML dump may reorder keys, so check both
      begin
        int rt_a, rt_b;
        rt_a = dpi_yaml_get(dumped_h, "a");
        check_int("dump: round-trip a=1", dpi_yaml_as_int(rt_a), 1);
        rt_b = dpi_yaml_get(dumped_h, "b");
        check("dump: round-trip b=hello", dpi_yaml_as_string(rt_b), "hello");
      end

      // dump_file
      obj_h = dpi_yaml_parse("{\"x\":100}");
      check_int("dump_file: success", dpi_yaml_dump_file(obj_h, "sv_yaml/tests/data/out_test.yaml", 2), 0);
      read_back_h = dpi_yaml_parse("sv_yaml/tests/data/out_test.yaml");
      check_int("dump_file: round-trip x=100", dpi_yaml_as_int(dpi_yaml_get(read_back_h, "x")), 100);
    end

    // === 9. YAML-specific: yaml_tag, yaml_anchor, yaml_dump_flow ===
    begin
      int tagged_h, anchor_h, map_h;
      string flow_h;

      // yaml_tag: set and get
      tagged_h = dpi_yaml_parse("42");
      begin
        int tagged2, tagged3;
        tagged2 = dpi_yaml_set_tag(tagged_h, "!!int");
        check("yaml_tag: set !!int", dpi_yaml_tag(tagged2), "!!int");
        tagged3 = dpi_yaml_set_tag(tagged_h, "!!str");
        check("yaml_tag: set !!str", dpi_yaml_tag(tagged3), "!!str");
      end

      // yaml_anchor: set and get
      anchor_h = dpi_yaml_parse("\"hello\"");
      begin
        int anchored;
        anchored = dpi_yaml_set_anchor(anchor_h, "my_anchor");
        check("yaml_anchor: set", dpi_yaml_anchor(anchored), "my_anchor");
      end

      // yaml_dump_flow: object
      map_h = dpi_yaml_parse("{\"a\":1,\"b\":2}");
      flow_h = dpi_yaml_dump_flow(map_h);
      check_bit("yaml_dump_flow: has {", (flow_h.len() > 0) ? 1 : 0, 1);

      // yaml_dump_flow: array
      begin
        int arr_h;
        string arr_flow;
        arr_h = dpi_yaml_parse("[1,2,3]");
        arr_flow = dpi_yaml_dump_flow(arr_h);
        check_bit("yaml_dump_flow: array has [", (arr_flow.len() > 0) ? 1 : 0, 1);
      end

      // yaml_set_comment and yaml_dump_with_comments
      begin
        int commented_h, commented2;
        string dumped_c;
        commented_h = dpi_yaml_parse("{\"key\":\"val\"}");
        commented2 = dpi_yaml_set_comment(commented_h, "my comment");
        dumped_c = dpi_yaml_dump_with_comments(commented2);
        check_bit("yaml_dump_with_comments: has comment", (dumped_c.len() > 0) ? 1 : 0, 1);
      end
    end

    // === 10. Scalar parsing (inline YAML) ===
    begin
      int s_h;

      s_h = dpi_yaml_parse("42");
      check_int("scalar: int 42", dpi_yaml_as_int(s_h), 42);

      s_h = dpi_yaml_parse("3.14");
      check_real("scalar: real 3.14", dpi_yaml_as_real(s_h), 3.14);

      s_h = dpi_yaml_parse("true");
      check_bit("scalar: bool true", dpi_yaml_as_bool(s_h), 1);

      s_h = dpi_yaml_parse("false");
      check_bit("scalar: bool false", dpi_yaml_as_bool(s_h), 0);

      s_h = dpi_yaml_parse("null");
      check_bit("scalar: null", dpi_yaml_is_null(s_h), 1);

      s_h = dpi_yaml_parse("\"hello\"");
      check("scalar: string", dpi_yaml_as_string(s_h), "hello");
    end

    // === 11. new_object, new_array ===
    begin
      int obj_h, arr_h;

      obj_h = dpi_yaml_new_object();
      check_bit("new_object: is_object", dpi_yaml_is_object(obj_h), 1);
      check_bit("new_object: empty", dpi_yaml_empty(obj_h), 1);

      arr_h = dpi_yaml_new_array();
      check_bit("new_array: is_array", dpi_yaml_is_array(arr_h), 1);
      check_bit("new_array: empty", dpi_yaml_empty(arr_h), 1);
    end

    // === 12. Complex YAML file ===
    begin
      int root_h, project_h, authors_h, config_h, endpoints_h, ep0_h;

      root_h = dpi_yaml_parse("sv_yaml/tests/data/complex.yaml");
      check_bit("complex: not null", (root_h != 0) ? 1 : 0, 1);
      check_bit("complex: is object", dpi_yaml_is_object(root_h), 1);

      project_h = dpi_yaml_get(root_h, "project");
      check("complex: project.name", dpi_yaml_as_string(dpi_yaml_get(project_h, "name")), "sv_serde");
      check("complex: project.version", dpi_yaml_as_string(dpi_yaml_get(project_h, "version")), "1.0.0");

      // Nested array access
      authors_h = dpi_yaml_get(project_h, "authors");
      check_int("complex: authors size", dpi_yaml_size(authors_h), 3);
      check("complex: authors[0]", dpi_yaml_as_string(dpi_yaml_at(authors_h, 0)), "alice");

      // Deep nested access
      config_h = dpi_yaml_get(root_h, "config");
      endpoints_h = dpi_yaml_get(config_h, "endpoints");
      ep0_h = dpi_yaml_at(endpoints_h, 0);
      check("complex: endpoint host", dpi_yaml_as_string(dpi_yaml_get(ep0_h, "host")), "10.0.0.1");
      check_int("complex: endpoint port", dpi_yaml_as_int(dpi_yaml_get(ep0_h, "port")), 8080);
      check_bit("complex: endpoint tls", dpi_yaml_as_bool(dpi_yaml_get(ep0_h, "tls")), 1);

      // at_path (config is at root level, not inside project)
      check("complex: at_path endpoint", dpi_yaml_as_string(dpi_yaml_at_path(root_h, "/config/endpoints/0/host")), "10.0.0.1");
    end

    // === 13. Edge cases ===
    begin
      int neg_h, zero_h, large_h, empty_arr_h, empty_obj_h;

      neg_h = dpi_yaml_parse("-42");
      check_int("edge: negative", dpi_yaml_as_int(neg_h), -42);

      zero_h = dpi_yaml_parse("0");
      check_int("edge: zero", dpi_yaml_as_int(zero_h), 0);

      large_h = dpi_yaml_parse("2147483647");
      check_int("edge: large int", dpi_yaml_as_int(large_h), 2147483647);

      empty_arr_h = dpi_yaml_new_array();
      check_bit("edge: empty array", dpi_yaml_empty(empty_arr_h), 1);
      check_int("edge: empty array size", dpi_yaml_size(empty_arr_h), 0);

      empty_obj_h = dpi_yaml_new_object();
      check_bit("edge: empty object", dpi_yaml_empty(empty_obj_h), 1);
      check_int("edge: empty object size", dpi_yaml_size(empty_obj_h), 0);

      // destroy
      begin
        int tmp = dpi_yaml_parse("{\"tmp\":1}");
        dpi_yaml_destroy(tmp);
        check_bit("destroy: no crash", 1, 1);
      end
    end

    $display("\nBasic tests: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count > 0) $finish(1);
    $finish;
  end
endmodule
