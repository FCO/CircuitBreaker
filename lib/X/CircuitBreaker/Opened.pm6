use X::CircuitBreaker;
unit class X::CircuitBreaker::Opened is X::CircuitBreaker;

method message { "The circuit is opened" }
