use X::CircuitBreaker::ShortCircuited;
use X::CircuitBreaker::Timeout;
use CircuitBreaker::Metric;
use CircuitBreaker::Status;
use SupplyTimeWindow;
use v6.d.PREVIEW;

multi multi-await(Awaitable $p)             { multi-await await $p }
multi multi-await($p where * !~~ Awaitable) { $p }

role CircuitBreaker::InternalExecutor[&cloned] {
    has Numeric                 $!timeout   = 1;
    has UInt                    $!retries   = 2;
    has CircuitBreaker::Status  $!status    = Closed;
    has Lock::Async             $!lst      .= new;
    has Supplier                $!supplier .= new;
    has Rat                     $.fail      = .1;
    has Supply                  $.metrics   = $!supplier
        .Supply
        .time-window(10)
        .map: {
            .reduce: { $^a + $^b }
        }
    ;

    method TWEAK (|) {
        start react whenever $!metrics {
            #say "{ .failures } / { .emit } => {(.failures / .emit) * 100}%";
            if .failures / .emit > $!fail {
                $!lst.protect: {
                    $!status = Opened
                }
            }
        }
    }

    method close {
        $!lst.protect: {
            $!status = Closed
        }
    }

    method status {
        $!lst.protect: {
            $!status
        }
    }

    method CALL-ME(|c) {
        X::CircuitBreaker::ShortCircuited.new.throw if $.status ~~ Opened;
        LEAVE $!supplier.emit: CircuitBreaker::Metric.new: :1emit;
        start multi-await self!RUN-ME(c)
    }

    method !RUN-ME(Capture \c) {
        KEEP $!supplier.emit: CircuitBreaker::Metric.new: :1successes;
        UNDO $!supplier.emit: CircuitBreaker::Metric.new: :1failures;
        my $prom = start { cloned(|c) };
        $prom .= then: sub ($_) {
            ENTER $!supplier.emit: CircuitBreaker::Metric.new: :1retries;
            CATCH {
                default {
                    return cloned(|c)
                }
            }
            return .result;
        } for ^$!retries;
        my $resp;
        {
            react {
                whenever Promise.in: $!timeout {
                    X::CircuitBreaker::Timeout.new(:$!timeout).throw;
                    done
                }

                whenever $prom -> $r {
                    $resp = $r;
                    done;
                }
            }
        }
        $resp
    }
}
role CircuitBreaker {
    has &!clone = self.clone;

    method TWEAK(|) {
        self does CircuitBreaker::InternalExecutor[&!clone] unless self ~~ CircuitBreaker::InternalExecutor[&!clone]
    }
}

multi trait_mod:<is>(Routine $r, Bool :$circuit-breaker!) is export { $r does CircuitBreaker }
