cmake_minimum_required(VERSION 3.20)

project(fifo_tb LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(verilator REQUIRED)
find_package(Catch2 3 REQUIRED)

add_executable(fifo_test
    tb/fifo/fifo_tb.cpp
    tb/main.cpp
)

verilate(
    fifo_test
    SOURCES
        rtl/fifo.sv
    TRACE_FST
)

target_include_directories(fifo_test PRIVATE
    tb
    tb/fifo
)

target_link_libraries(fifo_test PRIVATE
    Catch2::Catch2
)

# include(CTest)
# include(Catch)

# catch_discover_tests(fifo_test)
