#include <filesystem>
#include <catch2/catch_session.hpp>

#include "verilated.h"
#include "verilated_cov.h"


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    auto result = Catch::Session().run(argc, argv);

    // save coverage data for each simulation
    VerilatedCov::write((
        std::filesystem::path(argv[0]).filename().string() + ".dat").c_str()
    );

    return result;
}