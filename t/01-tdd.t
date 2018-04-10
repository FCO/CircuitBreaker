use Test;

use CircuitBreaker;
use X::CircuitBreaker::Timeout;

sub bla($i = 0) { 42 + $i }
my &ble := &bla but CircuitBreaker;
does-ok &ble, CircuitBreaker;
isa-ok ble(), Promise;
is await(ble), bla;
is await(ble 13), bla 13;

sub big-sleep($i = .1) { sleep $i; $i }
my &timeout := &big-sleep but CircuitBreaker;
does-ok &timeout, CircuitBreaker;
isa-ok timeout(), Promise;
is await(timeout), .1;
my $started = now;
throws-like { await(timeout 13) }, X::CircuitBreaker::Timeout, :timeout(1000), :message(/1000/);
cmp-ok now - $started, "<", 2;

my $tries = 0;
sub error($i = .1) { $tries++; sleep $i; die "big fat error" }
my &retry := &error but CircuitBreaker;
does-ok &retry, CircuitBreaker;
isa-ok my $p = retry(), Promise;
try await $p;
is $tries, 3;
$tries = 0;
throws-like { await(retry) }, X::AdHoc, :message(/"big fat error"/);
is $tries, 3;
$started = now;
throws-like { await(retry 13) }, X::CircuitBreaker::Timeout, :timeout(1000), :message(/1000/);
cmp-ok now - $started, "<", 2;
$started = now;
$tries = 0;
throws-like { await(retry .5) }, X::CircuitBreaker::Timeout, :timeout(1000), :message(/1000/);
is $tries, 3;
cmp-ok now - $started, "<", 1.5;

sub error2($i) { die "big fat error" if $tries++ != $i; $i }
my &retry2 := &error2 but CircuitBreaker;
does-ok &retry2, CircuitBreaker;
$tries = 0;
isa-ok $p = retry2(0), Promise;
await $p;
$tries = 0;
is await(retry2 0), 0;
is $tries, 1;
$tries = 0;
is await(retry2 1), 1;
is $tries, 2;
$tries = 0;
is await(retry2 2), 2;
is $tries, 3;
$tries = 0;
throws-like { await(retry2 3) }, X::AdHoc, :message(/"big fat error"/);
is $tries, 3;

done-testing
