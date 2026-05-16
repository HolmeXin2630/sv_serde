// sv_serde_all.sv — Single-file include for sv_serde library
//
// Usage:
//   vcs -full64 -sverilog \
//       +incdir+sv_serde/src \
//       +incdir+sv_json/src \
//       +incdir+sv_yaml/src \
//       sv_serde/src/sv_serde_all.sv your_test.sv \
//       sv_json/src/dpi/sv_json_dpi.cc sv_yaml/src/dpi/sv_yaml_dpi.cc sv_serde/src/dpi/serde_common.cc \
//       -CFLAGS "-std=c++14 -Isv_json/src/dpi -Isv_yaml/src/dpi -Isv_serde/src/dpi" \
//       -o simv
//
// Or with pre-built shared libraries:
//   vcs -full64 -sverilog \
//       +incdir+sv_serde/src \
//       +incdir+sv_json/src \
//       +incdir+sv_yaml/src \
//       sv_serde/src/sv_serde_all.sv your_test.sv \
//       -LDFLAGS "sv_json/src/dpi/libsv_json.so sv_yaml/src/dpi/libsv_yaml.so -Wl,-rpath,sv_json/src/dpi:sv_yaml/src/dpi" \
//       -o simv

`include "sv_serde_pkg.sv"
`include "sv_json_pkg.sv"
`include "sv_yaml_pkg.sv"
