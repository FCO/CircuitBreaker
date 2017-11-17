unit class CircuitBreaker::Metric;

has UInt    $.successes     = 0;
has UInt    $.failures      = 0;
has UInt    $.timeouts      = 0;
has UInt    $.rejections    = 0;
has Instant $.instant       = now;

multi method add(::?CLASS:D: ::?CLASS:D $_) {
    self.new:
        :successes\  ($.successes  + .successes ),
        :failures\   ($.failures   + .failures  ),
        :timeouts\   ($.timeouts   + .timeouts  ),
        :rejections\ ($.rejections + .rejections),
}

multi method add(::?CLASS:U: ::?CLASS:D $_) {
    .add: self
}

multi method add(::?CLASS:D: ::?CLASS:U $_) {
    self.new
}
