#!/usr/bin/env bash
set -euo pipefail

# run simulation tests and save coverage data
ctest --test-dir build --output-on-failure --timeout 300

# merge coverage data from multiple tests
verilator_coverage --write build/coverage.dat build/test_*.dat

# generate annotated coverage reports
verilator_coverage --annotate coverage build/coverage.dat