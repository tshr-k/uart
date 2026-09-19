cmake_minimum_required(VERSION 3.20)

project(uart LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(verilator REQUIRED)
find_package(Catch2 3 REQUIRED)

add_executable(test_fifo
    tb/fifo/fifo_tb.cpp
    tb/main.cpp
)

add_executable(test_counter
    tb/counter/counter_tb.cpp
    tb/main.cpp
)

verilate(
    test_fifo
    SOURCES
        rtl/fifo.sv
    TRACE_FST
)

verilate(
    test_counter
    SOURCES
        rtl/counter.sv
    TRACE_FST
)

target_include_directories(test_fifo PRIVATE
    tb
    tb/fifo
)

target_include_directories(test_counter PRIVATE
    tb
    tb/counter
)

target_link_libraries(test_fifo PRIVATE
    Catch2::Catch2
)

target_link_libraries(test_counter PRIVATE
    Catch2::Catch2
)

# include(CTest)
# include(Catch)

# catch_discover_tests(test_fifo)
