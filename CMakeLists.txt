cmake_minimum_required(VERSION 3.20)

project(uart LANGUAGES CXX)

include(CTest)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(verilator REQUIRED)
find_package(Catch2 3 REQUIRED)


function(add_verilator_test module_name has_tb)
    set(TEST_EXE_NAME test_${module_name})

    # build an executable even if no testbench exists, to check Verilator compilation
    set(TB_SRC)
    list(APPEND TB_SRC sim/main.cpp)
    if(${has_tb})
        list(APPEND TB_SRC sim/tests/${module_name}_tb.cpp)
    endif()

    add_executable(${TEST_EXE_NAME}
        ${TB_SRC}
    )

    # construct list of RTL sources from command line arguments
    set(RTL_SRC)
    foreach(dep_name IN LISTS ARGN)
        if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/rtl/${dep_name}.sv)
            list(APPEND RTL_SRC rtl/${dep_name}.sv)
        else()
            message(FATAL_ERROR "RTL dependency not found: ${dep_name}.sv")
        endif()
    endforeach()
    list(APPEND RTL_SRC rtl/${module_name}.sv)
    
    # attach Verilator-generated model to the test executable
    verilate(
        ${TEST_EXE_NAME}
        SOURCES ${RTL_SRC}
        TOP_MODULE ${module_name}
        PREFIX V${module_name}
        COVERAGE
        TRACE_FST
    )
    
    target_include_directories(${TEST_EXE_NAME} PRIVATE
        sim
        sim/ref
        sim/utils
    )

    target_link_libraries(${TEST_EXE_NAME} PRIVATE
        Catch2::Catch2
    )

    if(${has_tb})
        add_test(NAME ${TEST_EXE_NAME} COMMAND ${TEST_EXE_NAME})
    endif()
endfunction()


add_verilator_test(counter TRUE
    pkg/utils_pkg
)
add_verilator_test(tick_gen TRUE
    pkg/utils_pkg
    pkg/tick_gen_pkg
)
add_verilator_test(fifo TRUE
    pkg/utils_pkg
)
add_verilator_test(uart_rx TRUE
    pkg/uart_pkg
    pkg/utils_pkg
)
add_verilator_test(uart_tx TRUE
    pkg/uart_pkg
    pkg/utils_pkg
)
add_verilator_test(uart FALSE
    pkg/uart_pkg
    pkg/utils_pkg
    pkg/tick_gen_pkg
    tick_gen
    counter
    fifo
    uart_tx
    uart_rx
)