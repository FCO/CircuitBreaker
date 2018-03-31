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
            say "STATUS: {$!config.status}";
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
                resp.keep: $r;
                $!config.metric-emiter.emit: CircuitBreaker::Metric.new: :1successes;
                $!config.status = Closed;
            }
            CATCH {
                when X::CircuitBreaker::ShortCircuited {
                    $!config.metric-emiter.emit: CircuitBreaker::Metric.new: :1short-circuits;
                    self!error(resp, $_)
                }
                default {
                    say "AQUI";
                    $!config.open-circuit if $!config.status ~~ HalfOpened;
                    say $!config.status;
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
        resp.keep: def
    }
}

method stop {
    $!vow.keep
}
