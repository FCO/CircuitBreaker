use CircuitBreaker::Role;
unit class CircuitBreaker::Mock does CircuitBreaker::Role;
use X::CircuitBreakerMock::ShouldNeverBeCalled;
use X::CircuitBreaker::Timeout;
use CircuitBreaker::Status;
use CircuitBreaker::Utils;

my %responses;

method !call(Capture \c) {
    my $route = $*CircuitBreakerMock.get-route($!name);
    #note %responses;
    if $route {
        given $route.next {
            if .times < 0 {
                X::CircuitBreakerMock::ShouldNeverBeCalled.new(:cb-name($!name)).throw
            } else {
                .die;
            }
        }
    }
    &!exec(|c)
}

method CALL-ME(|c) {
    start {
        multi-await self!call(c)
    }
}
