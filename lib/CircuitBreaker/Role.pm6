unit role CircuitBreaker::Role does Callable;
use CircuitBreaker::Status;
use CircuitBreaker::DefaultNotSet;
use CircuitBreaker::Utils;

has Status      $.status        is rw = Closed;
has UInt        $.retries       is rw = 0;
has UInt        $.failures      is rw = 3;
has UInt        $.timeout       is rw = 1000;
has UInt        $.reset-time    is rw = 10000;
has             $.default       is rw = CircuitBreaker::DefaultNotSet;
has             &.exec;

method CALL-ME(|) {...}

my %defaults = (
    retries    => 0;
    failures   => 3;
    timeout    => 1000;
    reset-time => 10000;
);

method new(:&exec!, *%pars) {
    ($*CircuitBreakerMock || self).bless: |%defaults, |%pars, :&exec
}

method !has-default {$!default !~~ CircuitBreaker::DefaultNotSet}
method !get-default {
    multi-await $!default ~~ Callable ?? $!default() !! $!default
}

multi method config(::?CLASS:U: *%pars) {
    %defaults<retries   > = $_ with %pars<retries   >;
    %defaults<failures  > = $_ with %pars<failures  >;
    %defaults<timeout   > = $_ with %pars<timeout   >;
    %defaults<reset-time> = $_ with %pars<reset-time>;
    %defaults<default>    = $_ with %pars<default   >;
}

multi method config(::?CLASS:D: *%pars) {
    $!retries    = $_ with %pars<retries   >;
    $!failures   = $_ with %pars<failures  >;
    $!timeout    = $_ with %pars<timeout   >;
    $!reset-time = $_ with %pars<reset-time>;
    $!default    = $_ with %pars<default   >;
}
