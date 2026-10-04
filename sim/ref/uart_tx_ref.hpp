#include <cstdint>
#include <vector>


enum class parity_cfg_t {
    PARITY_NONE,
    PARITY_ODD,
    PARITY_EVEN
};

class UartTxRef {
public:

    UartTxRef() = default;
    UartTxRef(int data_bits, int stop_bits, parity_cfg_t parity_cfg)
        : data_bits_{data_bits}, stop_bits_{stop_bits}, parity_cfg_{parity_cfg} {}

    std::vector<int> get_frame(
        std::uint8_t data,
        bool parity_error = false,
        bool frame_error = false
    ) {
        std::vector<int> frame;

        // start bit
        frame.push_back(0);

        // data bits, LSB first
        for (int i = 0; i < data_bits_; ++i) {
            frame.push_back((data >> i) & 0x01);
        }

        // parity bit
        if (parity_cfg_ != parity_cfg_t::PARITY_NONE) {
            int parity_bit = 0;
            for (int i = 0; i < data_bits_; ++i) {
                parity_bit ^= (data >> i) & 0x01;
            }

            int parity_value = parity_cfg_ == parity_cfg_t::PARITY_EVEN
                ? parity_bit
                : !parity_bit;
            frame.push_back(parity_error ? !parity_value : parity_value);
        }

        // stop bits
        for (int i = 0; i < stop_bits_; ++i) {
            frame.push_back((frame_error && i == 0) ? 0 : 1);
        }

        return frame;
    }

    std::vector<int> get_idle(int cycles) {
        return std::vector<int>(cycles, 1);
    }

    std::size_t get_frame_length() {
        return get_frame(0).size();
    }

private:
    int data_bits_ = 8;
    int stop_bits_ = 1;  // tx doesn't support 1.5 stop bits
    parity_cfg_t parity_cfg_ = parity_cfg_t::PARITY_EVEN;
};