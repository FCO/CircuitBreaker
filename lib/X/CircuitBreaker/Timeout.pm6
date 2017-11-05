class X::CircuitBreaker is Exception {}
class X::CircuitBreaker::Opened is X::CircuitBreaker {
    method message { "The circuit is opened" }
}
class X::CircuitBreaker::Timeout is X::CircuitBreaker {
    has UInt $.timeout;
    method message { "CircuitBreaker timed out ($!timeout ms)" }
}
