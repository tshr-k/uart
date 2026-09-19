package utils_pkg;
    function automatic int unsigned max(
        input int unsigned a,
        input int unsigned b
    );
        // return the greater of a and b
        return (a > b) ? a : b;
    endfunction

    function automatic int unsigned min1_clog2(
        input int unsigned x
    );
        // return $clog2(x) but clamped to [1, infinity)
        return (x == 1) ? 1 : $clog2(x);
    endfunction
endpackage
