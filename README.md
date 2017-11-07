[![Build Status](https://travis-ci.org/FCO/CircuitBreaker.svg?branch=master)](https://travis-ci.org/FCO/CircuitBreaker)

CircuitBreaker

```
my &circuit-breaker := CircuitBreaker.new:
    :2retries,
    :3failures,
    :1000timeout,
    :10000reset-time,
    :exec(-> *@pars, :$of {
        "do something"
    })
;

my $response = await circuit-breaker "my", "list". :of<parameters>;
```
