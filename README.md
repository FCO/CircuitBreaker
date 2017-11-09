[![Build Status](https://travis-ci.org/FCO/CircuitBreaker.svg?branch=master)](https://travis-ci.org/FCO/CircuitBreaker)

CircuitBreaker

```
use CircuitBreaker;

CircuitBreaker.config:  # set new defaults
    :2retries,
    :3failures,
    :1000timeout,
    :10000reset-time
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
```

```
use CircuitBreaker;

my &cbreaker := circuit-breaker :default<ERROR>, -> $data {
    sleep rand * 2;
    $data
}

&cbreaker.config:   # configure de defined circuitbreaker
    :2retries,
    :3failures,
    :1000timeout,
    :10000reset-time
;
```

```
use CircuitBreaker;

my &my-circuit-breaker := CircuitBreaker.new:   # create a new object
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
