use Test;
use CircuitBreaker;
my %*CircuitBreaker;

sub cbreaker($name) is circuit-breaker {
    "do something with $name"
}

is await(cbreaker "my name"), "do something with my name", "It shouldn't timeout";

%*CircuitBreaker<cbreaker> = do given CircuitBreaker.mock-stack {
    .should-timeout(:once);
    .should-return(42, :twice);
    .should-execute(-> | {2 + 3}, :once);
}

is await(cbreaker "bla"), 5, "It should execute 2 + 3";
is await(cbreaker "bla"), 42, "It should return 42";
is await(cbreaker "bla"), 42, "again";
dies-ok { await cbreaker "my name" }, "It should timeout";

