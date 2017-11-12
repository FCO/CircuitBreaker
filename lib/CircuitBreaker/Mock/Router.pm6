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

sub times-msg($_) {
    when 1  {"once"     }
    when 2  {"twice"    }
    default {"$_ times" }
}

method verify {
    use Test;
    for %!routes.kv -> $name, $route {
        for |$route.responses {
            if 0 < .times < Inf {
                my $msg = "Circuit breaker '$name' should be called {times-msg .orig-times}, ";
                $msg ~= .orig-times == .times
                    ?? "but it wasn't"
                    !! "but was called only {times-msg .orig-times - .times}"
                ;
                flunk $msg
            }
        }
    }
}

method gist {
    %!routes.kv.map(-> $name, $route {"$name: [\n{$route.map(*.gist.indent: 5).join: "\n"}\n]"}).join: "\n"
}
