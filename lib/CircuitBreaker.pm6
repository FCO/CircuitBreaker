use X::CircuitBreaker::Timeout;
use CircuitBreaker::Metric;
use SupplyTimeWindow;
use v6.d.PREVIEW;

multi multi-await(Awaitable $p)             { multi-await await $p }
multi multi-await($p where * !~~ Awaitable) { $p }

role CircuitBreaker::InternalExecutor[&clone] {
    has UInt        $!retries   = 2;
    has Supplier    $!supplier .= new;
    has Supply      $.metrics   = $!supplier
        .Supply
        .time-window(10)
        .map: {
            .reduce: { $^a + $^b }
        };

    method CALL-ME(|c) {
        $!supplier.emit: CircuitBreaker::Metric.new: :1emit;
        start multi-await self!RUN-ME(c)
    }

    method !RUN-ME(Capture \c) {
        my $prom = Promise.start({ &clone(|c) })
            .then: sub ($_) {
                return .result;
                CATCH {
                    default {
                        for ^$!retries {
                            CATCH { default { next } }
                            return &clone(|c)
                        }
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
