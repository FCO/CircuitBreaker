unit class CircuitBreaker::Execution;
use X::CircuitBreaker::Timeout;

has &.exec is required;

method execute(Capture \c, :$retries = 0, :$timeout = 1000, Scheduler :$scheduler = $*SCHEDULER) {
    my $ret;
    my $prom = Promise.start: { self!run(c, :$retries) }, :$scheduler;
    react {
        whenever Promise.in: $timeout / 1000 {
            X::CircuitBreaker::Timeout.new.throw;
            done
        }

        whenever $prom -> $response {
            $ret = $response;
            done;
        }
    }
    $ret
}

method !run(Capture \c, :$retries) {
    my $ret;
    {
        $ret = &!exec(|c);
        CATCH {
            default {
                if $retries > 0 {
                    $ret = self!run(:retries($retries - 1), c)
                } else {
                    .rethrow
                }
            }
        }
    }
    $ret
}
