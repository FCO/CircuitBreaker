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

sub cbreaker is circuit-breaker{:default<ERROR>} {
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

## Testing:

```
use Test;
use CircuitBreaker;
my %*CircuitBreaker;

sub cbreaker($name) is circuit-breaker {
    "do something with $name"
}

is await(cbreaker "my name"), "do something with my name", "It shouldn't timeout";

%*CircuitBreaker<cbreaker> = do given CircuitBreaker.mock-stack {
    .should-timeout(:once);
    .should-return(42, :twice);
    .should-execute(-> | {2 + 3}, :once);
}

is await(cbreaker "bla"), 5, "It should execute 2 + 3";
is await(cbreaker "bla"), 42, "It should return 42";
is await(cbreaker "bla"), 42, "again";
dies-ok { await cbreaker "my name" }, "It should timeout";
```
