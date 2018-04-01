use X::CircuitBreaker;
unit class X::CircuitBreaker::Timeout is X::CircuitBreaker;

has UInt $.timeout = 0;

method message { "Timed Out! Execution durated more than $!timeout ms" }
