unit class CircuitBreaker does Callable;
use X::CircuitBreaker::Timeout;
enum Status <Closed Opened HalfOpened>;

has Status      $.status        = Closed;
has UInt        $.retries       = 0;
has UInt        $.failures      = 3;
has UInt        $.timeout       = 1000;
has UInt        $.reset-time    = 10000;
has             &.exec;
has             $.default;
has Bool        $!has-default   = False;

has UInt        $.failed    = 0;
has Exception   $!last-fail;
has Lock        $!lock     .= new;
has UInt        $!tries     = 0;

multi method TWEAK(:$default!, |) {
    $!has-default = True;
}

multi method TWEAK(|) {
    $!has-default = False;
}

method CALL-ME(|c --> Promise) is hidden-from-backtrace {
    $!tries = 0;
    start {
        my $ret = await self!execute(|c);
        $!failed = 0;
        CATCH {
            default {
                $!failed++;
                if $!has-default {
                    $ret = $!default;
                } else {
                    .rethrow
                }
            }
        }
        $ret
    }
}

method !execute(|c --> Promise) is hidden-from-backtrace {
    $!tries++;
	my $prom = Promise.new;
	my \vow  = $prom.vow;

    if $!status ~~ Opened {
        vow.break: X::CircuitBreaker::Opened.new;
        return $prom
    }

    start {
        react {
            whenever Promise.in($!timeout / 1000) {
                try vow.break(X::CircuitBreaker::Timeout.new: :$!timeout);
                done();
            }
            whenever start { &!exec(|c) } -> \ret {
                vow.keep: ret;
                $!last-fail = Nil;
                $!failed  = 0;
                done();
            }
        }
        CATCH {
            when X::CircuitBreaker      {
                .rethrow
            }
            when $!tries > $!retries    {
                vow.break: $_
            }
            default {
                $!last-fail //= $_;
                if $!failed >= $!failures or $!status ~~ HalfOpened {
                    $!status = Opened;
		    Promise.in($!reset-time)
                        .then: {
                            $!status = HalfOpened;
                        }
	            ;
                }
                my $ret = await self!execute(|c);
                vow.keep: $ret;
                CATCH {
                    when X::CircuitBreaker  { vow.break: $_ }
                    default                 { vow.break: .message }
                }
            }
        }
    }
    $prom
}
