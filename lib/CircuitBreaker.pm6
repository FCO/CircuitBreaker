use CircuitBreaker::Role;
unit class CircuitBreaker does CircuitBreaker::Role;
use CircuitBreaker::Executor;
use X::CircuitBreaker::Timeout;
use X::CircuitBreaker::Opened;
use CircuitBreaker::Status;
use CircuitBreaker::DefaultNotSet;
use CircuitBreaker::Utils;
use CircuitBreaker::Mock::Router;
use experimental :macros;

has Bool        $!has-default   = False;

has atomicint   $.failed        = 0;
has Exception   $!last-fail;

has Lock        $!lock         .= new;

multi trait_mod:<is>(Routine $r, Bool :$circuit-breaker!) is export {
    trait_mod:<is>($r, :circuit-breaker{})
}

multi trait_mod:<is>(Routine $r, :%circuit-breaker!) is export {
    my $a = $r.clone;
    my &cb := CircuitBreaker.new(:exec($a), :name($a.name), |%circuit-breaker);
    $r.wrap: -> |c {
        cb(|c)
    }
    $r does role CircuitBreaker {has $.circuit-breaker = &cb}
}


sub circuit-breaker(&exec, *%pars) is export {CircuitBreaker.new: :&exec, |%pars}

method mock-router(::?CLASS:U:) {$ //= CircuitBreaker::Mock::Router.new}

macro circuit-breaker-mock is export {
    quasi {
        $*CircuitBreakerMock //= CircuitBreaker::Mock::Router.new
    }
}

method CALL-ME(|capture --> Promise) {
    start {
        my $ret;
        if $!status ~~ Opened {
            $!failed⚛++;
            if self!has-default {
                $ret = self!get-default
            } else {
                X::CircuitBreaker::Opened.new.throw;
            }
        } else {
            my $retries = $!status ~~ HalfOpened ?? 0 !! $!retries;
            my $executor = CircuitBreaker::Executor.new:
                :$retries,
                :&!exec
            ;
            react {
                whenever Promise.in($!timeout / 1000) {
                    X::CircuitBreaker::Timeout.new(:$!timeout).throw
                }
                whenever start {$executor.execute(capture)} -> $response {
                    $ret = multi-await $response;
                    $!failed ⚛= 0;
                    $!lock.protect: { $!status = Closed }
                    done
                }
            }
            CATCH {
                default {
                    $!failed⚛++;
                    if $!failed >= $!failures {
                        $!lock.protect: { $!status = Opened }
                        Promise.in($!reset-time / 1000)
                            .then: {
                                $!lock.protect: { $!status = HalfOpened }
                            }
                        ;
                    }
                    if self!has-default {
                        $ret = self!get-default
                    } else {
                        $!lock.protect: { $!last-fail = $_ }
                        .rethrow
                    }
                }
            }
        }
        $ret
    }
}
