unit class CircuitBreaker::Execution;
use X::CircuitBreaker::Timeout;

has     &.exec is required;

method execute(Capture \c, :$retries = 0, :$timeout = 1000, Supplier :$emitter, Scheduler :$scheduler = $*SCHEDULER) {
    my $ret;
    my $prom = Promise.start: { self!run(c, :$retries, :$emitter) }, :$scheduler;
    react {
        whenever Promise.in: $timeout / 1000 {
            $emitter.emit: CircuitBreaker::Metric.new: :1timeout;
            X::CircuitBreaker::Timeout.new(:$timeout).throw;
            done
        }

        whenever $prom -> $response {
            $ret = $response;
            done;
        }
    }
    $ret
}

method !run(Capture \c, :$retries, :$emitter) {
    my $ret;
    {
        $ret = &!exec(|c);
        CATCH {
            default {
                if $retries > 0 {
                    $emitter.emit: CircuitBreaker::Metric.new: :1retries;
                    $ret = self!run(:retries($retries - 1), c)
                } else {
                    .rethrow
                }
            }
        }
    }
    $ret
}
