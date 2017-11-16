use X::CircuitBreaker;
unit class X::CircuitBreaker::TooManyRequests is X::CircuitBreaker;

method message { "Too many requests" }
