use Test;
use CircuitBreaker;

my $*CircuitBreakerMock;
circuit-breaker-mock.test.should-run(:always);

sub get-cbreaker($name = "test") {
    circuit-breaker {$++}, :name($name)
}


my &cb := get-cbreaker;
is await(cb), $++ for ^10;
