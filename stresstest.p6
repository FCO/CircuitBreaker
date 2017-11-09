use CircuitBreaker;

CircuitBreaker.config:
    :2retries,
    :3failures,
    :1000timeout,
    :3000reset-time
;

my &cbreaker := circuit-breaker :default<ERROR>, -> $data {
    sleep rand * 2;
    $data
}

my Promise @proms;
my $counter = 0;

loop {
    @proms .= grep: Planned;
    for @proms.elems ..^ 5 {
        @proms.push: cbreaker($counter++).then: {printf "\r% 10s => %d", .result, @proms.elems}
    }
    await Promise.anyof: @proms
}
