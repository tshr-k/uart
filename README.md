# UART

A parameterised UART in SystemVerilog, including transmit and receive paths, baud-rate tick generation, buffering, and error handling. It includes C++/Verilator simulations with coverage plus bounded formal checks for the RTL.

## Repository organisation

- `rtl/`: synthesizable SystemVerilog modules and shared packages.
- `sim/`: C++ simulation entry point, testbenches, reference models, and
  utilities.
- `formal/`: SystemVerilog formal properties.
- `scripts/`: commands for simulation, coverage, and formal verification.
- `coverage/`: generated annotated coverage reports.
- `traces/`: generated FST waveform traces from simulation.
- `verilog/`: generated Verilog used as input to EBMC.
- `CMakeLists.txt`: CMake targets for building and testing the Verilator
  models.

## Dependencies

The project requires:

- CMake 3.20 or newer and a C++20 compiler.
- Verilator with CMake integration, including `verilator_coverage`.
- Catch2 3.x development libraries.
- The [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build), `source`d before formal verification; it provides Yosys and the `read_slang` frontend used to synthesize the SystemVerilog RTL into simpler Verilog.
- [EBMC](https://github.com/ebmc/ebmc) for bounded formal verification.
- Bash and CTest (normally installed with CMake).

The formal verification script expects the OSS CAD Suite environment at
`$HOME/tools/oss-cad-suite/environment`.

The rich SystemVerilog used for the RTL must first be synthesized into Verilog for the formal tool's use. Also, packages and parameter overrides are avoided in the formal verification wrapper modules since EBMC doesn't yet support these features.