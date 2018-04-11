use X::CircuitBreaker::ShortCircuited;
use X::CircuitBreaker::Timeout;
use CircuitBreaker::Metric;
use CircuitBreaker::Status;
use SupplyTimeWindow;
use v6.d.PREVIEW;

multi multi-await(Awaitable $p)             { multi-await await $p }
multi multi-await($p where * !~~ Awaitable) { $p }

role CircuitBreaker::InternalExecutor[&clone] {
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
        my $prom = Promise.start({ &clone(|c) })
            .then: sub ($_) {
                return .result;
                KEEP $!supplier.emit: CircuitBreaker::Metric.new: :1successes;
                CATCH {
                    default {
                        for ^$!retries {
                            $!supplier.emit: CircuitBreaker::Metric.new: :1retries;
                            CATCH { default { next } }
                            return &clone(|c)
                        }
                        $!supplier.emit: CircuitBreaker::Metric.new: :1failures;
                        $!.rethrow
                    }
                }
            }
        ;
        my $resp;
        {
            react {
                whenever Promise.in: 1 {
                    X::CircuitBreaker::Timeout.new(:1000timeout).throw;
                    done
                }

                whenever $prom -> $r {
                    $resp = $r;
                    done;
                }
            }
            CATCH {
                when X::CircuitBreaker::Timeout {
                    .rethrow
                }
                default {
                    .rethrow
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
