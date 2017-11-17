unit class CircuitBreaker::Executor;
use X::CircuitBreaker::ShortCircuited;
use CircuitBreaker::Execution;
use CircuitBreaker::Status;
use CircuitBreaker::Config;
use CircuitBreaker::Metric;

has Channel                     $.channel is required;
has CircuitBreaker::Config      $.config  is required;
has Promise                     $.finished     .= new;
has                             $!vow           = $!finished.vow;
has CircuitBreaker::Execution   $!execution;

method TWEAK(:&exec, |) {
    $!execution .= new: :&exec
}

method start {
    react {
        whenever $!finished {
            done
        }
        whenever $!channel -> $data {
            if $!config.status ~~ Opened {
                $data.response.break: X::CircuitBreaker::ShortCircuited.new;
            } else {
                my $retries = $!config.retries;
                my $r = $!execution.execute:
                    :retries($retries),
                    :timeout($!config.timeout),
                    $data.capture,
                ;
                $data.response.keep: $r;
                $!config.metric-emiter.emit: CircuitBreaker::Metric.new: :1successes;
                CATCH {
                    default {
                        $!config.metric-emiter.emit: CircuitBreaker::Metric.new: :1failures;
                        $data.response.break: $_
                    }
                }
            }
        }
    }
}

method stop {
    $!vow.keep
}
