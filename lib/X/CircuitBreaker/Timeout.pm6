use X::CircuitBreaker;
unit class X::CircuitBreaker::Timeout is X::CircuitBreaker;

has UInt $.timeout;
method message { "CircuitBreaker timed out ($!timeout ms)" }
