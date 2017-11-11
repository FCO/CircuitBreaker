unit class CircuitBreaker::Mock::Route;
use CircuitBreaker::Mock::Response;

has CircuitBreaker::Mock::Response  @!responses;
has                                 $.router;

method TWEAK(|) {
    $.create-response.should-never-be-called
}

method FALLBACK($name where {CircuitBreaker::Mock::Response.^can($_)}, |c) {
    $.create-response."$name"(|c)
}

method create-response {
    my \new = CircuitBreaker::Mock::Response.new: :parent(self);
    @!responses.unshift: new;
    new
}

method next {
    my $response = @!responses.head;
    @!responses.shift if --$response.times == 0;
    $response
}

multi method Bool(::?CLASS:D:) {@!responses.elems > 0}
multi method Bool(::?CLASS:U:) {False}

method gist {
    "route: [\n{@!responses>>.gist>>.indent(5).join: "\n"}\n]"
}
