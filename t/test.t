use Test;
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
is &cb.failed, 1, "Its counting the filures";
throws-like {await cb}, X::CircuitBreaker::Timeout, "Should timeout";
is &cb.failed, 2, "Its counting the filures";
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
		#await cb :die<Bye>;
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

done-testing
