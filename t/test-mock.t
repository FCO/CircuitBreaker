use Test;
use Test::Scheduler;
use CircuitBreaker;
use CircuitBreaker::Mock;

isa-ok CircuitBreaker.mock, CircuitBreaker::Mock;

sub get-cbreaker {
    circuit-breaker {$++}
}

my $*CircuitBreakerMock = CircuitBreaker.mock;

my &cb := get-cbreaker;
isa-ok &cb, CircuitBreaker::Mock;
is await(cb), $++ for ^10
