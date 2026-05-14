#include "Vsv_yaml_test.h"
#include "verilated.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vsv_yaml_test* top = new Vsv_yaml_test;
    while (!Verilated::gotFinish()) {
        top->eval();
    }
    delete top;
    return 0;
}
