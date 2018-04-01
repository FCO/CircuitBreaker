unit class CircuitBreaker::MockStack does Callable;
use CircuitBreaker::Mock;

has CircuitBreaker::Mock @.mocks;

method CALL-ME(&cb, Capture \c) {
    self.next.(&cb, c)
}

method TWEAK(|) {
    $.create-mock.should-never-be-called
}

method FALLBACK($name where {CircuitBreaker::Mock.^can($_)}, |c) {
    $.create-mock."$name"(|c)
}

method create-mock {
    my \new = CircuitBreaker::Mock.new: :parent(self);
    @!mocks.unshift: new;
    new
}

method next {
    my $mock = @!mocks.head;
    @!mocks.shift if --$mock.times == 0;
    $mock
}

multi method Bool(::?CLASS:D:) {@!mocks.elems > 0}
multi method Bool(::?CLASS:U:) {False}

method gist {
    "route: [\n{@!mocks>>.gist>>.indent(5).join: "\n"}\n]"
}
