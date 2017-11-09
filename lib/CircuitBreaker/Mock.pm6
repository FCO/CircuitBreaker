use CircuitBreaker::Role;
unit class CircuitBreaker::Mock does CircuitBreaker::Role;
use CircuitBreaker::Status;
use CircuitBreaker::Utils;

has $.mock-response is rw;

method CALL-ME(|c) { start { multi-await $!mock-response // &!exec(|c) } }
