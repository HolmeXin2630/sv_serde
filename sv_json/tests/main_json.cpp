#include "Vsv_json_test.h"
#include "verilated.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vsv_json_test* top = new Vsv_json_test;
    while (!Verilated::gotFinish()) {
        top->eval();
    }
    delete top;
    return 0;
}