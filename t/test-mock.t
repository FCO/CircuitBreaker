use Test;
use Test::Scheduler;
use CircuitBreaker;
use CircuitBreaker::Mock;
use X::CircuitBreakerMock::ShouldNotBeCalled;

isa-ok CircuitBreaker.mock, CircuitBreaker::Mock;

sub get-cbreaker {
    circuit-breaker {$++}, :name<test>
}

my $*CircuitBreakerMock = CircuitBreaker.mock;

my &cb := get-cbreaker;
isa-ok &cb, CircuitBreaker::Mock;
is await(cb), $++ for ^10;

#$*CircuitBreakerMock.test.should-die-with(X::AdHoc.new(payload => "deu ruim"));
#throws-like { await(cb) }, X::AdHoc;
#throws-like { await(cb) }, X::CircuitBreakerMock::ShouldNotBeCalled;
#
#$*CircuitBreakerMock.test.should-timeout(:twice);
#throws-like { await(cb) }, X::CircuitBreaker::Timeout;
#throws-like { await(cb) }, X::CircuitBreaker::Timeout;
#
#$*CircuitBreakerMock.test.should-never-be-called;
#throws-like { await(cb) }, X::CircuitBreakerMock::ShouldNotBeCalled;

done-testing
