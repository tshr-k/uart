#include <filesystem>
#include <catch2/catch_session.hpp>

#include "verilated.h"
#include "verilated_cov.h"


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    auto result = Catch::Session().run(argc, argv);

    // save coverage data for each simulation
    const auto executable_path = std::filesystem::absolute(argv[0]);
    const auto coverage_path =
        executable_path.parent_path() / (executable_path.filename().string() + ".dat");
    VerilatedCov::write(coverage_path.c_str());

    return result;
}