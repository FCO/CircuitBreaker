unit role CircuitBreaker;
use CircuitBreaker::Executor;
use CircuitBreaker::Config;
use CircuitBreaker::Data;
use X::CircuitBreaker::TooManyRequests;

my %cache{Capture};

has Supplier                    $!control  .= new;
has Supplier                    $.supplier .= new;
has Supply                      $.supply    = $!supplier.Supply;
has Supplier                    $.bleed    .= new;
has Supplier                    $.status   .= new;
has Channel                     $.channel;
has UInt                        $.threads   = 1;
has CircuitBreaker::Executor    @.executors;
has                             &.exec;
has CircuitBreaker::Config      $.config   .= new:
    :name(self.name),
    :$!control,
    :bleed($!bleed.Supply)
;

method compose(&!exec) {
    start react whenever $!bleed {
        .response.break: X::CircuitBreaker::TooManyRequests.new
    }
    $!channel = $!supply
        .throttle(
            $!config.reqps - 1, 1,
            :$!control,
            :$!status,
            :$!bleed,
            :1vent-at
        )
        .Channel
    ;
    for ^$!threads {
        start {
            my $ex = CircuitBreaker::Executor.new(
                :$!channel,
                :$!config,
                :&!exec
            );
            @!executors.push: $ex;
            $ex.start
        }
    }
}

method CALL-ME(|c) {
    my Promise $p .= new;
    $!supplier.emit: CircuitBreaker::Data.new: :capture(c), :response($p.vow);
    $p
}

multi trait_mod:<is>(Routine $r, :$circuit-breaker!) is export {
    my &clone = $r.clone;
    $r does CircuitBreaker;
    $r.compose: &clone;
    $r
}
