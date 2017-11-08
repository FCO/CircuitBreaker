unit class CircuitBreaker does Callable;
use CircuitBreaker::Executor;
use X::CircuitBreaker::Timeout;
use X::CircuitBreaker::Opened;
enum Status <Closed Opened HalfOpened>;

has Status      $.status        = Closed;
has UInt        $.retries       = 0;
has UInt        $.failures      = 3;
has UInt        $.timeout       = 1000;
has UInt        $.reset-time    = 10000;
has             &.exec;
has             $.default       = class DefaultNotSet {};
has Bool        $!has-default   = False;

has atomicint   $.failed        = 0;
has Exception   $!last-fail;

has Lock        $!lock         .= new;

multi multi-await(Promise $p)   { multi-await await $p }
multi multi-await($p)           { $p }

method !has-default {$!default !~~ DefaultNotSet}
method !get-default {
    multi-await $!default ~~ Callable ?? $!default() !! $!default
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
