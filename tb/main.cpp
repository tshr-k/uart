#include <catch2/catch_session.hpp>

#include "verilated.h"


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    return Catch::Session().run(argc, argv);
}