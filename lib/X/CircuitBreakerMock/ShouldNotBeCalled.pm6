use X::CircuitBreaker;
unit class X::CircuitBreakerMock::ShouldNotBeCalled is X::CircuitBreaker;

has Str $!name = "";
method message { "CircuitBreaker '$!name' was called" }
