unit class CircuitBreaker::Mock::Router;
use CircuitBreaker::Mock::Route;
use CircuitBreaker::Mock;

has CircuitBreaker::Mock::Route %.routes;

method class {CircuitBreaker::Mock}

method FALLBACK($name) {
    $.create-route($name)
}

method get-route($name) {%!routes{$name}}

method create-route(Str $name) {
    %!routes{$name} //= CircuitBreaker::Mock::Route.new: :router(self)
}
