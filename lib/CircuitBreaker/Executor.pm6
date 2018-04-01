unit class CircuitBreaker::Executor;
use X::CircuitBreaker::ShortCircuited;
use CircuitBreaker::DefaultNotSet;
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
            my \resp = $data.response;
            if $!config.status ~~ Opened {
                X::CircuitBreaker::ShortCircuited.new.throw
            } else {
                my $retries = $!config.retries;
                my $r = $!execution.execute:
                    :scheduler($!config.scheduler),
                    :retries($retries),
                    :timeout($!config.timeout),
                    $data.capture,
                ;
                $!config.status = Closed;
                resp.keep: $r;
                $!config.metric-emiter.emit: CircuitBreaker::Metric.new: :1successes;
            }
            CATCH {
                when X::CircuitBreaker::ShortCircuited {
                    $!config.metric-emiter.emit: CircuitBreaker::Metric.new: :1short-circuits;
                    self!error(resp, $_)
                }
                default {
                    $!config.open-circuit if $!config.status ~~ HalfOpened;
                    $!config.metric-emiter.emit: CircuitBreaker::Metric.new: :1failures;
                    self!error(resp, $_)
                }
            }
        }
    }
}

method !error(\resp, $_) {
    my \def = $!config.default;
    if def ~~ CircuitBreaker::DefaultNotSet {
        resp.break: $_
    } else {
        if def ~~ Callable {
            resp.keep: def.()
        } else {
            resp.keep: def
        }
    }
}

method stop {
    $!vow.keep
}
