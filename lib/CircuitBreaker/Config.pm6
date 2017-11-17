unit class CircuitBreaker::Config;
use CircuitBreaker::DefaultNotSet;
use CircuitBreaker::Status;

my %cache;

has Str         $.name              is rw;
has Status      $.status            is rw = Closed;
has UInt        $.retries           is rw = 0;
has UInt        $.failures          is rw = 3;
has UInt        $.timeout           is rw = 1000;
has UInt        $.reset-time        is rw = 10000;
has             $.default           is rw = CircuitBreaker::DefaultNotSet;
has UInt        $.reqps             is rw = 100;
has UInt        $.threads           is rw = 1;
has Supplier    $.control           is required;
has Supply      $.bleed             is required;
has             $.circuit-breaker   is required;

method TWEAK(|) {%cache{$!name} = self}

method cache(::?CLASS:U:) {%cache}

method for(::?CLASS:U: $name) is rw {%cache{$name}}

method reqps is rw {
    my $reqps   := $!reqps;
    my $control := $!control;
    Proxy.new:
        FETCH => method ()      {$reqps},
        STORE => method ($v)    {
            $control.emit: "limit:{$v - 1}";
            $reqps = $v
        }
}

method threads is rw {
    my $threads   := $!threads;
    my &cbreaker  := $!circuit-breaker;
    Proxy.new:
        FETCH => method ()      {$threads},
        STORE => method ($v)    {
            &cbreaker.fix-threads: $threads;
            $threads = $v
        }
}
