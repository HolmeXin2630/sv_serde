# sv_yaml Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build sv_yaml — YAML library with same API as sv_json, backed by rapidyaml, with YAML-specific features (multi-doc, comments, anchors, tags, flow style).

**Architecture:** Same pattern as sv_json — C++ DPI engine manages YAML objects via handles, SV package wraps with class API. Verilator tests call DPI directly.

**Tech Stack:** SystemVerilog-2012, Verilator, rapidyaml v0.12.1, C++17

---

## Task 1: Scaffold + Download rapidyaml

**Files:**
- Create: `sv_serde/sv_yaml/src/dpi/rapidyaml-0.12.1.hpp` (download)
- Create: `sv_serde/sv_yaml/tests/data/*.yaml` (test data)
- Modify: `sv_serde/Makefile.verilator` (add yaml target)

- [ ] Create directories
- [ ] Download rapidyaml single-header from `https://github.com/biojppm/rapidyaml/releases/download/v0.12.1/rapidyaml-0.12.1.hpp`
- [ ] Create test YAML files (simple.yaml, anchors.yaml, comments.yaml, multiline.yaml, multi_doc.yaml, complex.yaml)
- [ ] Add `run_test_yaml` target to Makefile.verilator
- [ ] Commit

## Task 2: C++ DPI Header + Engine

**Files:**
- Create: `sv_serde/sv_yaml/src/dpi/sv_yaml_dpi.h`
- Create: `sv_serde/sv_yaml/src/dpi/sv_yaml_dpi.cc`

- [ ] Create header with all DPI functions (common + YAML-specific)
- [ ] Create implementation using rapidyaml
- [ ] Verify compilation: `g++ -std=c++17 -c -Isv_yaml/src/dpi sv_yaml/src/dpi/sv_yaml_dpi.cc -o /dev/null`
- [ ] Commit

## Task 3: SV Package + Class

**Files:**
- Create: `sv_serde/sv_yaml/src/sv_yaml_pkg.sv`

- [ ] Create package with types, DPI imports, sv_yaml class
- [ ] Commit

## Task 4: Basic Test + Build

**Files:**
- Create: `sv_serde/sv_yaml/tests/sv_yaml_test.sv`
- Create: `sv_serde/sv_yaml/tests/main_yaml.cpp`

- [ ] Create test module with DPI-level tests (same pattern as sv_json)
- [ ] Create Verilator main
- [ ] Run `make -f Makefile.verilator run_test_yaml`
- [ ] Debug and fix issues
- [ ] Commit

## Task 5: YAML-Specific Tests

**Files:**
- Modify: `sv_serde/sv_yaml/tests/sv_yaml_test.sv`

- [ ] Add multi-document tests
- [ ] Add comment tests
- [ ] Add anchor/alias tests
- [ ] Add tag tests
- [ ] Add flow style dump tests
- [ ] Run tests
- [ ] Commit

## Task 6: Complex YAML Tests

**Files:**
- Modify: `sv_serde/sv_yaml/tests/sv_yaml_test.sv`
- Create: `sv_serde/sv_yaml/tests/data/complex.yaml`

- [ ] Create complex.yaml with all YAML features
- [ ] Add comprehensive tests
- [ ] Run tests
- [ ] Commit

## Task 7: Final Verification + CLAUDE.md Update

- [ ] Update CLAUDE.md with sv_yaml info
- [ ] Run full test suite
- [ ] Commit
