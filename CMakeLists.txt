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

add_executable(test_uart_rx
    # tb/uart_rx/uart_rx_tb.cpp
    tb/main.cpp
)

add_executable(test_uart_tx
    # tb/uart_tx/uart_tx_tb.cpp
    tb/main.cpp
)

add_executable(test_tick_gen
    # tb/tick_gen/tick_gen_tb.cpp
    tb/main.cpp
)

verilate(
    test_fifo
    SOURCES
        rtl/utils_pkg.sv
        rtl/fifo.sv
    TOP_MODULE fifo
    PREFIX Vfifo
    TRACE_FST
)

verilate(
    test_counter
    SOURCES
        rtl/counter.sv
    TRACE_FST
)

verilate(
    test_uart_rx
    SOURCES
        rtl/utils_pkg.sv
        rtl/uart_pkg.sv
        rtl/uart_rx.sv
    TOP_MODULE uart_rx
    PREFIX Vuart_rx
    TRACE_FST
)

verilate(
    test_uart_tx
    SOURCES
        rtl/utils_pkg.sv
        rtl/uart_pkg.sv
        rtl/uart_tx.sv
    TOP_MODULE uart_tx
    PREFIX Vuart_tx
    TRACE_FST
)

verilate(
    test_tick_gen
    SOURCES
        rtl/utils_pkg.sv
        rtl/tick_gen.sv
    TOP_MODULE tick_gen
    PREFIX Vtick_gen
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

target_include_directories(test_uart_rx PRIVATE
    tb
    tb/uart_rx
)

target_include_directories(test_uart_tx PRIVATE
    tb
    tb/uart_tx
)

target_include_directories(test_tick_gen PRIVATE
    tb
    tb/tick_gen
)

target_link_libraries(test_fifo PRIVATE
    Catch2::Catch2
)

target_link_libraries(test_counter PRIVATE
    Catch2::Catch2
)

target_link_libraries(test_uart_rx PRIVATE
    Catch2::Catch2
)

target_link_libraries(test_uart_tx PRIVATE
    Catch2::Catch2
)

target_link_libraries(test_tick_gen PRIVATE
    Catch2::Catch2
)

# include(CTest)
# include(Catch)

# catch_discover_tests(test_fifo)
