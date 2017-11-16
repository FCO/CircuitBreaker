unit class CircuitBreaker::Execution;

has &.exec is required;

method execute(Capture \c, :$retries = 0) {
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
