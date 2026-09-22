package utils_pkg;
    function automatic int unsigned max(
        input int unsigned a,
        input int unsigned b
    );
        return (a > b) ? a : b;
    endfunction

    // Compute $clog2(x) but clamped to [1, infinity)
    function automatic int unsigned min1_clog2(
        input int unsigned x
    );
        return (x == 1) ? 1 : unsigned'($clog2(x));
    endfunction
endpackage
