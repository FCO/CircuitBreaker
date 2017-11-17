unit class CircuitBreaker::Execution;
use X::CircuitBreaker::Timeout;

has &.exec is required;

method execute(Capture \c, :$retries = 0, :$timeout = 1000) {
    my $ret;
    react {
        whenever Promise.in: $timeout {
            X::CircuitBreaker::Timeout.new.throw;
            done
        }

        whenever start { self!run(c, :$retries) } -> $response {
            $ret = $response
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
                    $ret = $.execute :retries($retries - 1), c
                } else {
                    .rethrow
                }
            }
        }
    }
    $ret
}
