package CheckProxy::Command::loadproxy;
use Mojo::Base 'Mojolicious::Command';

use Mojo::UserAgent;
use IO::Scalar;
use Text::CSV;
use Locale::Country;

has description => 'Load proxy.';
has usage       => "Usage: perl script/listee loadproxy\n";

use constant PROXY_LIST_CSV =>
  'http://proxy-list.org/english/yourproxylists/speed-32/limit-5000/2160d21702744f14f1ec1ace669f51d6.csv';

sub run {
  my $command = shift;

  my $pg  = $command->app->pg;
  my $log = $command->app->log;

  my $ua = Mojo::UserAgent->new(max_redirects => 10, request_timeout => 15);
  my $tx = $ua->get(&PROXY_LIST_CSV);

  unless ($tx->success) {
    my $err = $tx->error;
    my $msg = $err->{code} ?
      qq{[loadproxy] $err->{code} response: $err->{message}} :
      qq{[loadproxy] Connection error: $err->{message}};
    $log->error($msg);
    return;
  }

  my $data = $tx->res->body;

  if ($data =~ m/error/i) {
    $log->error(qq{[loadproxy] $data});
    return;
  }

  my $io_data = IO::Scalar->new(\$data);
  my $parsed_data = Text::CSV->new({binary => 1})->getline_all($io_data);

  if (@$parsed_data <= 1 && @{$parsed_data->[0]} <= 1) {
    $log->warn(qq{[loadproxy] csv file is empty. $data});
    return;
  }

  my $proxies = {};

  shift @$parsed_data;

  if (!$parsed_data || !@$parsed_data || scalar(@$parsed_data) < 50) {
    $log->warn(q{[loadproxy] little data in proxyfile});
    return;
  }

  my $db = $pg->db;

  $db->query(q{truncate proxy});

  for my $proxy (@$parsed_data) {
    my ($addr, $country, $city, $scheme) = @$proxy;
    my ($host, $port) = split /:/, $addr;

    $port = int ($port // 0);
    my $country_code  = uc (country2code($country) // '');
    $scheme = lc $scheme;

    $log->debug(qq{[loadproxy] host or port not defined. $addr}) unless $port && $host;

    eval { $db->query(q{insert into proxy values (?, ?, ?, ?)}, $host, $port, $country_code, $scheme) };
    $log->error(qq{[loadproxy] $@\n$addr, $country, $city, $scheme}) if $@ && $@ !~ m/error:\s*duplicate key/i;
  }

  $log->debug(q{[loadproxy] Load proxy successfully});
}

1;
