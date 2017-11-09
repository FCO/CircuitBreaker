unit class CircuitBreaker does Callable;
use CircuitBreaker::Executor;
use X::CircuitBreaker::Timeout;
use X::CircuitBreaker::Opened;
enum Status <Closed Opened HalfOpened>;

has Status      $.status        is rw = Closed;
has UInt        $.retries       is rw = 0;
has UInt        $.failures      is rw = 3;
has UInt        $.timeout       is rw = 1000;
has UInt        $.reset-time    is rw = 10000;
has             $.default       is rw = class DefaultNotSet {};
has             &.exec;
has Bool        $!has-default   = False;

has atomicint   $.failed        = 0;
has Exception   $!last-fail;

has Lock        $!lock         .= new;

my %defaults = (
    retries    => 0;
    failures   => 3;
    timeout    => 1000;
    reset-time => 10000;
);

method new(:&exec!, *%pars) {
    self.bless: |%defaults, |%pars, :&exec
}

multi method config(::?CLASS:U: *%pars) {
    %defaults<retries   > = $_ with %pars<retries   >;
    %defaults<failures  > = $_ with %pars<failures  >;
    %defaults<timeout   > = $_ with %pars<timeout   >;
    %defaults<reset-time> = $_ with %pars<reset-time>;
    %defaults<default>    = $_ with %pars<default   >;
}

multi method config(::?CLASS:D: *%pars) {
    $!retries    = $_ with %pars<retries   >;
    $!failures   = $_ with %pars<failures  >;
    $!timeout    = $_ with %pars<timeout   >;
    $!reset-time = $_ with %pars<reset-time>;
    $!default    = $_ with %pars<default   >;
}

sub circuit-breaker(&exec, *%pars) is export {CircuitBreaker.new: :&exec, |%pars}

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
