#pragma once

#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <queue>


// T is std::uint*_t
template<typename T>
class FifoRef {
public:
    explicit FifoRef(std::size_t depth) : depth_{depth} {}

    bool full() const {
        return q_.size() == depth_;
    }

    bool empty() const {
        return q_.empty();
    }

    bool try_read(T& value) const {
        if (empty()) return false;
        
        value = q_.front();
        return true;
    }

    bool try_pop(T& value) {
        if (!try_read(value)) return false;

        q_.pop();
        return true;
    }

    bool try_write(T x) {
        if (full()) return false;

        q_.push(x);
        return true;
    }

private:
    std::size_t depth_;
    std::queue<T> q_;
};