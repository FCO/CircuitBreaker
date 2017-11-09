use Test;
use Test::Scheduler;
use CircuitBreaker;
use X::CircuitBreaker::Timeout;
use X::CircuitBreaker::Opened;

my &cb := CircuitBreaker.new:
    :2retries,
    :3failures,
    :1000timeout,
    :exec(-> Int $times = 1, :$return, :$die {
        state $num //= 0;
        do with $return {
            $_
        } orwith $die {
            die $die
        } else {
            do given ++$num {
                when 1 .. 3   { die "Deu ruim!!!" }
                when 4        { sleep 2 }
                default       { $_ * $times }
            }
        }
    })
;

throws-like {await cb}, X::AdHoc,                   "Should die with the 'last-fail'";
is &cb.failed, 1, "Its counting the failures";
throws-like {await cb}, X::CircuitBreaker::Timeout, "Should timeout";
is &cb.failed, 2, "Its counting the failures";
subtest {
    is await(cb),              5,  "Should return the number 5";
    is await(cb 2),            12, "Should return the number 12";
    is await(cb 3),            21, "Should return the number 21";
    is await(cb :42return),    42, "Should return the number 42";
}, "Should live and return the right answer";

subtest {
    for ^3 {
        is &cb.status.key, "Closed", "Circuit is still closed";
        throws-like {await cb :die<Bye>}, X::AdHoc, "It should die";
        is &cb.failed, $_ + 1, "Its counting the failures";
    }

    for ^3 {
        is &cb.status.key, "Opened", "Circuit had opened";
        throws-like {await cb :die<Bye>}, X::CircuitBreaker::Opened, "It should die";
        is &cb.failed, $_ + 4, "Its counting the failures";
    }
}, "Should change status";

my &cb2 := CircuitBreaker.new:
    :2retries,
    :3failures,
    :default("default response"),
    :exec{die "Bye"}
;

subtest {
    for ^3 {
        is &cb2.status.key, "Closed", "Circuit is still closed";
        is await(cb2), "default response", "It should return the default response";
        is &cb2.failed, $_ + 1, "Its counting the failures";
    }

    for ^3 {
        is &cb2.status.key, "Opened", "Circuit had opened";
        is await(cb2), "default response", "It should return the default response";
        is &cb2.failed, $_ + 4, "Its counting the failures";
    }
}, "Should change status with default response";

{
    my $*SCHEDULER = Test::Scheduler.new;
    my &cb3 := CircuitBreaker.new:
        :2retries,
        :3failures,
        :1000reset-time,
        :exec(-> $die = True {state $num //= 0; ++$num; die "Bye" if $die; $num})
    ;

    subtest {
        for ^3 {
            is &cb3.status.key, "Closed", "Circuit is still closed";
            throws-like {await cb3 True}, X::AdHoc, "It should die";
            is &cb3.failed, $_ + 1, "Its counting the failures";
        }
        is &cb3.status.key, "Opened", "Circuit is opened";
        throws-like {await cb3}, X::CircuitBreaker::Opened, "It should die";
        $*SCHEDULER.advance-by(1);
        is &cb3.status.key, "HalfOpened", "Circuit is halfopened";
        throws-like {await cb3}, X::AdHoc, "It should die";
        is &cb3.status.key, "Opened", "Circuit is opened again";
        $*SCHEDULER.advance-by(1);
        is &cb3.status.key, "HalfOpened", "Circuit is halfopened";
        is await(cb3 False), 11, "Tried";
        is &cb3.status.key, "Closed", "Circuit is opened again";
    }, "Test halfopen";
}

my &cb4 := CircuitBreaker.new:
    :exec{start start start start start {42}}
;

is await(cb4), 42, "Accept promise inside a promise inside ...";

my &cb5 := CircuitBreaker.new:
    :default{13 + 29},
    :exec{die "Bye"}
;

is await(cb5), 42, "Accept default as code";

my &cb6 := CircuitBreaker.new:
    :default{start {13 + 29}},
    :exec{die "Bye"}
;

is await(cb6), 42, "Accept default as code returning promise";

isa-ok circuit-breaker({;}), CircuitBreaker, "circuit-breaker function";

my $a = circuit-breaker({;}, :1retries, :1failures, :1timeout, :1reset-time, :1default);
is $a.retries,      1;
is $a.failures,     1;
is $a.timeout,      1;
is $a.reset-time,   1;
is $a.default,      1;

$a.retries      =   2;
$a.failures     =   2;
$a.timeout      =   2;
$a.reset-time   =   2;
$a.default      =   2;

is $a.retries,      2;
is $a.failures,     2;
is $a.timeout,      2;
is $a.reset-time,   2;
is $a.default,      2;

done-testing
