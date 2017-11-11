use Test;
use Test::Scheduler;
use CircuitBreaker;
use CircuitBreaker::Mock;
use X::CircuitBreakerMock::ShouldNeverBeCalled;

plan 17;

isa-ok CircuitBreaker.mock-router, CircuitBreaker::Mock::Router;

my $*CircuitBreakerMock = CircuitBreaker.mock-router;

sub get-cbreaker($name = "test") {
    circuit-breaker {$++}, :name($name)
}

$*CircuitBreakerMock.test.should-run(:always);

my &cb := get-cbreaker;
isa-ok &cb, CircuitBreaker::Mock;
is await(cb), $++ for ^10;

$*CircuitBreakerMock.test.should-never-be-called;
$*CircuitBreakerMock.test.should-die-with(X::AdHoc.new(payload => "deu ruim"), :once);
throws-like { await(cb) }, X::AdHoc;
throws-like { await(cb) }, X::CircuitBreakerMock::ShouldNeverBeCalled;

$*CircuitBreakerMock.test.should-timeout(:twice);
throws-like { await(cb) }, X::CircuitBreaker::Timeout;
throws-like { await(cb) }, X::CircuitBreaker::Timeout;

$*CircuitBreakerMock.test.should-never-be-called;
throws-like { await(cb) }, X::CircuitBreakerMock::ShouldNeverBeCalled;
