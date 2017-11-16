use X::CircuitBreaker;
unit class X::CircuitBreaker::ShortCircuited is X::CircuitBreaker;

method message { "The circuit is opened" }
