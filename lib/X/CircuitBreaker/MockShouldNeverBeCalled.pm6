use X::CircuitBreaker;
unit class X::CircuitBreaker::MockShouldNeverBeCalled is X::CircuitBreaker;

has $.cb-name;
method message { "CircuitBreaker '$!cb-name' was called but never should be called" }
