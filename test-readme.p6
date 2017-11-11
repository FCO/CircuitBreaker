use Test;
use CircuitBreaker;
my $*CircuitBreakerMock = CircuitBreaker.mock-router;

my &cbreaker := circuit-breaker :name<test>, -> $name {
    "do something with $name"
}

is await(cbreaker "my name"), "do something with my name", "It shouldn't timeout";

$*CircuitBreakerMock.test.should-timeout(:once);

dies-ok { await cbreaker "my name" }, "It should timeout";
