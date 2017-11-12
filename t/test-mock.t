use Test;
use Test::Scheduler;
use CircuitBreaker;
use CircuitBreaker::Mock;
use X::CircuitBreakerMock::ShouldNeverBeCalled;

plan 18;

isa-ok CircuitBreaker.mock-router, CircuitBreaker::Mock::Router;

my $*CircuitBreakerMock; # You have to create the dynamic var before use the macro

sub get-cbreaker($name = "test") {
    circuit-breaker {$++}, :name($name)
}

circuit-breaker-mock.test.should-run(:always);

my &cb := get-cbreaker;
isa-ok &cb, CircuitBreaker::Mock;
is await(cb), $++ for ^10;

$*CircuitBreakerMock.test.should-never-be-called;
circuit-breaker-mock.test.should-die-with(X::AdHoc.new(payload => "deu ruim"), :once);
throws-like { await(cb) }, X::AdHoc;
throws-like { await(cb) }, X::CircuitBreakerMock::ShouldNeverBeCalled;

$*CircuitBreakerMock.test.should-timeout(:twice);
throws-like { await(cb) }, X::CircuitBreaker::Timeout;
throws-like { await(cb) }, X::CircuitBreaker::Timeout;

circuit-breaker-mock.test.should-never-be-called;
throws-like { await(cb) }, X::CircuitBreakerMock::ShouldNeverBeCalled;

todo "it should fail...";
subtest {
    $*CircuitBreakerMock.test2.should-timeout(:twice);
    circuit-breaker-mock.test2.should-run(:3times);
    my &cb2 := circuit-breaker :name<test2>, {;};
    await cb2;
    $*CircuitBreakerMock.verify;
}
