cmake_minimum_required(VERSION 3.20)

project(uart LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(verilator REQUIRED)
find_package(Catch2 3 REQUIRED)


<<<<<<< Updated upstream
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
=======
function(add_verilator_test module_name has_tb)
    set(TEST_EXE_NAME test_${module_name})

    # build an executable even if no testbench exists, to check Verilator compilation
    set(TB_SRC)
    list(APPEND TB_SRC tb/main.cpp)
    if(${has_tb})
        list(APPEND TB_SRC tb/${module_name}/${module_name}_tb.cpp)
    endif()

    add_executable(${TEST_EXE_NAME}
        ${TB_SRC}
    )

    # construct list of RTL sources from command line arguments
    set(RTL_SRC)
    foreach(pkg_name IN LISTS ARGN)
        list(APPEND RTL_SRC rtl/${pkg_name}.sv)
    endforeach()
    list(APPEND RTL_SRC rtl/${module_name}.sv)
    
    # attach Verilator-generated model to the test executable
    verilate(
        ${TEST_EXE_NAME}
        SOURCES ${RTL_SRC}
        TOP_MODULE ${module_name}
        PREFIX V${module_name}
        TRACE_FST
    )
    
    target_include_directories(${TEST_EXE_NAME} PRIVATE
        tb
        tb/${module_name}
    )

    target_link_libraries(${TEST_EXE_NAME} PRIVATE
        Catch2::Catch2
    )
endfunction()


add_verilator_test(counter TRUE)
add_verilator_test(tick_gen TRUE utils_pkg tick_gen_pkg)
add_verilator_test(fifo TRUE utils_pkg)
add_verilator_test(uart_rx FALSE utils_pkg uart_pkg)
add_verilator_test(uart_tx FALSE utils_pkg uart_pkg)
>>>>>>> Stashed changes
