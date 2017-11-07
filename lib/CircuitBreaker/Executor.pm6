unit class CircuitBreaker::Executor;
use X::CircuitBreaker::NoMoreRetries;

has UInt        $.retries   = 0;
has             &.exec;

method execute(Capture \c, UInt :$tries = 0) {
    my $ret;
    {
        $ret = &!exec(|c);
        CATCH {
            default {
                my $orig-exception = $_;
                if $tries < $!retries {
                    $ret = $.execute(c, :tries($tries + 1));
                    CATCH {
                        when X::CircuitBreaker::NoMoreRetries {
                            $orig-exception.rethrow if $tries == 0;
                            proceed
                        }
                        default { .rethrow }
                    }
                } else {
                    $orig-exception.rethrow if $!retries == 0;
                    X::CircuitBreaker::NoMoreRetries.new(:$!retries).throw
                }
            }
        }
    }
    $ret
}
