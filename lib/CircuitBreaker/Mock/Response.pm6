unit class CircuitBreaker::Mock::Response;
use X::CircuitBreaker::Timeout;

has Str         $.wtd;
has             $.parent        is required;
has             $.times         is rw       = Inf;
has             $.orig-times                = $!times;
has Exception   $.exception                 = Nil;

method die {
    .throw with $!exception
}

method Bool { $!times > 0 }

sub times(Int :$times, Bool :$once, Bool :$twice, Bool :$never, Bool :$always, Bool :$forever) {
    #die "You should use only one of <x time times once twice>"
    #    unless one($times, $once, $twice).defined
    #        or none($times, $once, $twice).defined
    #;

    do if  $never    { 0      }
    elsif  $once     { 1      }
    elsif  $twice    { 2      }
    elsif  $always   { Inf    }
    elsif  $forever  { Inf    }
    orwith $times    { $times }
    else             { Inf    }
}

method should-never-be-called {
    $!wtd           = "never be called";
    $!orig-times    = $!times = 0;
    $!parent
}

method should-run(*%times) {
    $!wtd           = "run";
    $!orig-times    = $!times = $_ with times(|%times);
    $!parent
}

method should-timeout(*%times) {
    $!wtd           = "timeout";
    $!orig-times    = $!times     = $_ with times(|%times);
    $!exception     = X::CircuitBreaker::Timeout.new(timeout => 0);
    $!parent
}

method should-die-with(Exception $!exception, *%times) {
    $!wtd           = "die with";
    $!orig-times    = $!times = $_ with times(|%times);;
    $!parent
}

method gist { "$!times x $!wtd" }
