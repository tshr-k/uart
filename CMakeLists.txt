cmake_minimum_required(VERSION 3.20)

project(uart LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(verilator REQUIRED)
find_package(Catch2 3 REQUIRED)


function(add_verilator_test module_name requires_utils_pkg requires_uart_pkg)
    add_executable(test_${module_name}
        tb/${module_name}/${module_name}_tb.cpp
        tb/main.cpp
    )

    set(RTL_SOURCES)
    if(requires_utils_pkg)
        list(APPEND RTL_SOURCES rtl/utils_pkg.sv)
    endif()
    if(requires_uart_pkg)
        list(APPEND RTL_SOURCES rtl/uart_pkg.sv)
    endif()
    list(APPEND RTL_SOURCES rtl/${module_name}.sv)

    verilate(
        test_${module_name}
        SOURCES ${RTL_SOURCES}
        TOP_MODULE ${module_name}
        PREFIX V${module_name}
        TRACE_FST
    )
    
    target_include_directories(test_${module_name} PRIVATE
        tb
        tb/${module_name}
    )

    target_link_libraries(test_${module_name} PRIVATE
        Catch2::Catch2
    )
endfunction()


add_verilator_test(counter  FALSE FALSE)
add_verilator_test(tick_gen TRUE  FALSE)
add_verilator_test(fifo     TRUE  FALSE)
add_verilator_test(uart_rx  TRUE  TRUE)
add_verilator_test(uart_tx  TRUE  TRUE)
