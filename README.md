[![Build Status](https://travis-ci.org/FCO/CircuitBreaker.svg?branch=master)](https://travis-ci.org/FCO/CircuitBreaker)

CircuitBreaker

```
use CircuitBreaker;

my &cbreaker := circuit-breaker {
    sleep rand * 2;
    $^data
}

&cbreaker.retries    = 2;
&cbreaker.failures   = 3;
&cbreaker.timeout    = 1000;
&cbreaker.reset-time = 10000;

my Promise @proms;
my $counter = 0;

loop {
    @proms .= grep: Planned;
    for @proms.elems ..^ 5 {
        @proms.push: cbreaker($counter++).then: {print "\r{.result}\t\t{@proms.elems}"}
    }
    await Promise.anyof: @proms
}
```

```
my &my-circuit-breaker := CircuitBreaker.new:
    :2retries,
    :3failures,
    :1000timeout,
    :10000reset-time,
    :exec(-> *@pars, :$of {
        "do something"
    })
;

my $response = await my-circuit-breaker "my", "list". :of<parameters>;
```
