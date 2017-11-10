use CircuitBreaker::Role;
unit class CircuitBreaker::Mock does CircuitBreaker::Role;
use X::CircuitBreakerMock::ShouldNotBeCalled;
use X::CircuitBreaker::Timeout;
use CircuitBreaker::Status;
use CircuitBreaker::Utils;

my %responses;

method !call(Capture \c) {
    with %responses{$!name} {
        if .elems {
            given .head {
                if .times == 0 {
                    X::CircuitBreakerMock::ShouldNotBeCalled.new(:$!name).throw
                } else {
                    .times--;
                    %responses{$!name}.shift unless .Bool;
                    .die;
                }
            }
        } else {

        }
    }
    &!exec(|c)
}

method CALL-ME(|c) {
    start {
        multi-await self!call(c)
    }
}

class Response {
    has CircuitBreaker::Mock    $.parent    is required;
    has                         $.times     is rw;
    has Exception               $.exception = Nil;

    method die {
        .throw with $!exception
    }

    method Bool { $!times > 0 }

    sub times(Int :$times, Bool :$once, Bool :$twice, Bool :$never) {
        #die "You should use only one of <x time times once twice>"
        #    unless one($times, $once, $twice).defined
        #        or none($times, $once, $twice).defined
        #;

        if     $never    { return 0      }
        elsif  $once     { return 1      }
        elsif  $twice    { return 2      }
        orwith $times    { return $times }
        1
    }

    method should-never-be-called {
        $!times = 0;
        $!parent
    }

    method should-always-run {
        $!times = Inf;
        $!parent
    }

    method should-timeout(*%times) {
        $!times     = $_ with times(|%times);
        $!exception = X::CircuitBreaker::Timeout.new(timeout => 0);
        $!parent
    }

    method should-die-with(Exception $!exception, *%times) {
        $!times = $_ with times(|%times);;
        $!parent
    }
}

method FALLBACK($name) {
    my $resp = Response.new: :parent(self);
    %responses{$name}.push: $resp;
    if %responses{$name}.elems > 1 {
        my $first = Response.new: :parent(self);
        $first.should-never-be-called;
        %responses{$name}.push: $first
    }
    $resp
}
