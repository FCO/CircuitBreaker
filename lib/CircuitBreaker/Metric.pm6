unit class CircuitBreaker::Metric;

has UInt    $.emit                  = 0;
has UInt    $.successes             = 0;
has UInt    $.failures              = 0;
has UInt    $.timeouts              = 0;
has UInt    $.rejections            = 0;
has UInt    $.bad-requests          = 0;
has UInt    $.short-circuits        = 0;
has UInt    $.fallback-emit         = 0;
has UInt    $.fallback-failures     = 0;
has UInt    $.fallback-rejections   = 0;
has UInt    $.fallback-missings     = 0;

has Instant $.instant           = now;

multi method add(::?CLASS:D: ::?CLASS:D $_) {
    my %pars = self.^attributes
        .grep({ .type ~~ UInt })
        .map({ .name.substr(2) })
        .map(-> $meth {
            $meth => self."$meth"() + ."$meth"()
        })
    ;
    self.new: |%pars
}

multi method add(::?CLASS:U: ::?CLASS:D $_) {
    ::?CLASS.new
}

multi method add(::?CLASS:D: ::?CLASS:U $_) {
    ::?CLASS.new
}

multi method add(::?CLASS:U: ::?CLASS:U $_) {
    ::?CLASS.new
}
