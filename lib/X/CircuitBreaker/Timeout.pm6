use X::CircuitBreaker;
unit class X::CircuitBreaker::Timeout is X::CircuitBreaker;

method message { "Timed Out" }
