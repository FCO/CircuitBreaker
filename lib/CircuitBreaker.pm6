unit role CircuitBreaker;
use CircuitBreaker::Executor;
use CircuitBreaker::Config;
use CircuitBreaker::Data;
use CircuitBreaker::Metric;
use CircuitBreaker::Status;
use X::CircuitBreaker::TooManyRequests;

my %cache{Capture};

has Supplier                    $!control  .= new;
has Supplier                    $.supplier .= new;
has Supply                      $.supply    = $!supplier.Supply;
has Supplier                    $.bleed    .= new;
has Supplier                    $.status   .= new;
has Channel                     $.channel;
has CircuitBreaker::Executor    @.executors;
has                             &.exec;
has Scheduler                   $.scheduler = $*SCHEDULER;
has CircuitBreaker::Config      $.config   .= new:
    :circuit-breaker(self),
    :$!control,
    :bleed($!bleed.Supply),
    :$!scheduler
;

method compose(&!exec) {
    Promise.start: {
        react {
            whenever $!bleed {
                $!config.metric-emiter.emit: CircuitBreaker::Metric.new: :1rejections;
                .response.break: X::CircuitBreaker::TooManyRequests.new
            }

            whenever $!config.metrics {
                next unless .defined and .failures >= $!config.failures;
                $!config.open-circuit unless $!config.status ~~ HalfOpened;
            }
        }
    }, :$!scheduler;
    $!channel = $!supply
        .throttle(
            :$!scheduler,
            $!config.reqps - 1, 1,
            :$!control,
            :$!status,
            :$!bleed,
            :1vent-at
        )
        .Channel
    ;

    $.fix-threads($!config.threads)
}

method fix-threads(UInt $threads) {
    if $threads > @!executors.elems {
        for @!executors.elems ..^ $threads {
            Promise.start: {
                my $ex = CircuitBreaker::Executor.new(
                    :$!channel,
                    :$!config,
                    :&!exec
                );
                @!executors.push: $ex;
                $ex.start
            }, $!scheduler;
        }
    } elsif $threads < @!executors.elems {
        for @!executors.splice: $threads {
            .stop
        }
    } elsif $!scheduler !=== $!config.scheduler {
        $!scheduler = $!config.scheduler;
        for @!executors.splice {
            Promise.start: {
                my $ex = CircuitBreaker::Executor.new(
                    :$!channel,
                    :$!config,
                    :&!exec
                );
                @!executors.push: $ex;
                $ex.start
            }, $!scheduler;
            .stop;
        }
    }
}

method CALL-ME(|c) {
    my Promise $p .= new;
    $!config.metric-emiter.emit: CircuitBreaker::Metric.new: :1emit;
    $!supplier.emit: CircuitBreaker::Data.new: :capture(c), :response($p.vow);
    $p
}

multi trait_mod:<is>(Routine $r, Bool :$circuit-breaker!) is export {
    my &clone = $r.clone;
    $r does CircuitBreaker;
    $r.compose: &clone;
    start $r.config.metric-emiter.emit: CircuitBreaker::Metric.new for ^20;
    $r.^attributes.first({ .name ~~ '$!name' }).set_value($r, &clone.name);
    $r
}

multi trait_mod:<is>(Routine $r, :%circuit-breaker!) is export {
    trait_mod:<is>($r, :circuit-breaker);
    for %circuit-breaker.kv -> $key, $value {
        given $r.config {
            ."$key"() = $value
        }
    }
    $r
}

multi trait_mod:<is>(Block $r, :$circuit-breaker!) is export {
    trait_mod:<is>(sub (|c) {$r.(|c)}, :$circuit-breaker);
}

sub circuit-breaker(&sub, *%circuit-breaker) is export { trait_mod:<is>(&sub, :%circuit-breaker) }
