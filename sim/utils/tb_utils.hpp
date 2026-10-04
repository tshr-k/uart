// header-only verilator testbench utils

#pragma once

#include <cstdint>
#include <format>
#include <stdexcept>
#include <string_view>
#include <memory>

#include "verilated.h"
#include "verilated_fst_c.h"


template<typename Dut>
class Clock;

template <typename Dut>
class Sim {
public:
    Sim(Dut* dut, VerilatedFstC* trace)
        : dut_{dut}
        , trace_{nullptr}
        , clk{*this}
        , event_number_{0}
    {
        if (dut == nullptr) {
            throw std::invalid_argument("dut cannot be nullptr");
        }
    }

    friend class Clock<Dut>;

    void eval() {
        dut_->eval();
    }

    void set_trace(VerilatedFstC* trace) {
        trace_ = trace;
    }

    void dump() {
        if (trace_) {
            trace_->dump(event_number_++);
        }
    }

    void eval_dump() {
        eval();
        dump();
    }

    Clock<Dut> clk;
    
private:
    // Sim owns neither dut nor trace
    Dut* dut_;
    VerilatedFstC* trace_;
    uint64_t event_number_;  // not the same as physical time
};


template <typename Dut>
class Clock {
// the user needn't ever manually manipulate dut->clk
public:
    Clock(Sim<Dut>& sim) : sim_(sim) {}

    void posedge() {
        sim_.dut_->clk = 1;
        sim_.eval_dump();
    }
    
    void negedge() {
        sim_.dut_->clk = 0;
        sim_.eval_dump();
    }
    
    void cycle() {
        posedge();
        negedge();
    }

    void cycles(unsigned int n) {
        for (unsigned int i = 0; i < n; ++i) {
            cycle();
        }
    }

private:
    Sim<Dut>& sim_;
};


template<typename Dut>
struct DutFixture {
    // DutFixture owns dut and trace
    std::unique_ptr<Dut> dut;
    Sim<Dut> sim;

    DutFixture() : dut{std::make_unique<Dut>()}, sim{dut.get(), trace_.get()} {}

    // no copying allowed
    DutFixture(const DutFixture&) = delete;
    DutFixture& operator=(const DutFixture&) = delete;

    ~DutFixture() {
        if (trace_open_) {
            trace_->close();
        }
    }

    void open_trace(std::string_view wave_dir, std::string_view wave_name) {
        if (trace_open_) {
            throw std::logic_error("trace already open");
        }

        trace_ = std::make_unique<VerilatedFstC>();
        dut->trace(trace_.get(), 99);
        sim.set_trace(trace_.get());
        
        trace_->open(std::format("{}/{}.fst", wave_dir, wave_name).c_str());
        trace_open_ = true;
    }

    void dut_reset();

private:
    std::unique_ptr<VerilatedFstC> trace_ = nullptr;
    bool trace_open_ = false;
};