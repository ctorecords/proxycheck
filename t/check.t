use Mojo::Base -strict;

use Test::More;
use Test::CheckProxy;

my $t = Test::CheckProxy->new('CheckProxy');

$t->get_ok('/check?ip=127.0.0.1')->status_is(200)->json_is('/anonymous' => 1);
$t->get_ok('/check?ip=127.0.0.1' => {'X' => '127a0s0d1'})->status_is(200)->json_is('/anonymous' => 1);

$t->get_ok('/check?ip=127.0.0.1' => {'X' => '127.0.0.1'})->status_is(200)->json_is('/anonymous' => 0);
$t->get_ok('/check?ip=127.0.0.1' => {'X' => 'qwe127.0.0.1asd'})->status_is(200)->json_is('/anonymous' => 0);

$t->get_ok('/check?ip=127.0.0.1' => {'X-host' => 'qwe127.0.0.1'})->status_is(200)->json_is('/anonymous' => 0);

done_testing;
