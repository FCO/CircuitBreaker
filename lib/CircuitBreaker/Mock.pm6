unit class CircuitBreaker::Mock does Callable;
use X::CircuitBreaker::Timeout;
use X::CircuitBreaker::MockShouldNeverBeCalled;

has Str         $.wtd;
has             $.parent        is required;
has             $.times         is rw       = Inf;
has             $.orig-times                = $!times;
has Exception   $.exception                 = Nil;
has             $.return;
has             &.execute;

method CALL-ME(&cb, Capture \c) {
    if $!times < 0 {
        X::CircuitBreaker::MockShouldNeverBeCalled.new(:cb-name(&cb.name)).throw
    }
    .throw with $!exception;
    .return with $!return;
    .(|c, :&cb).return with &!execute;
    &cb.exec.(|c)
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

method should-timeout(Bool :$wait-for-it, *%times) {
    $!wtd           = "timeout";
    $!orig-times    = $!times     = $_ with times(|%times);
    &!execute       = -> :&cb, | {
        sleep &cb.config.timeout / 1000 if $wait-for-it;
        X::CircuitBreaker::Timeout.new(timeout => &cb.config.timeout).throw
    }
    $!parent
}

method should-die-with(Exception $!exception, *%times) {
    $!wtd           = "die with";
    $!orig-times    = $!times = $_ with times(|%times);;
    $!parent
}

method should-return($!return, *%times) {
    $!wtd           = "die with";
    $!orig-times    = $!times = $_ with times(|%times);;
    $!parent
}

method should-execute(&!execute, *%times) {
    $!wtd           = "die with";
    $!orig-times    = $!times = $_ with times(|%times);;
    $!parent
}

method gist { "$!times x $!wtd" }
