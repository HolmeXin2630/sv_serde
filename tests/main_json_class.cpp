#include "Vtest_json_class.h"
#include "verilated.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtest_json_class* top = new Vtest_json_class;
    while (!Verilated::gotFinish()) {
        top->eval();
    }
    delete top;
    return 0;
}
