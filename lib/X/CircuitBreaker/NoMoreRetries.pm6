use X::CircuitBreaker;
unit class X::CircuitBreaker::NoMoreRetries is X::CircuitBreaker;

has UInt $.retries;
method message { "Alread tried $!retries times" }
