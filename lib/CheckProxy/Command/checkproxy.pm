package CheckProxy::Command::checkproxy;
use Mojo::Base 'Mojolicious::Command';

use Mojo::UserAgent;
use Time::HiRes 'time';

use constant LOCK_TIME => 5 * 60;

has description => 'Check proxy.';
has usage       => "Usage: perl script/listee checkproxy\n";

sub run {
  my $command = shift;

  my $pg  = $command->app->pg;
  my $log = $command->app->log;

  my $lock_time = time;

  my $lock = $pg->db->query(q{update locks set lock = true, updated_at = now() where name = 'checkproxy' and lock = false});
  return unless $lock->rows;

  my $results = $pg->db->query(q{
    select * from proxy
    where updated_at + interval '1 hour' < now() or updated_at is null
    order by updated_at desc
  });

  return finish($command->app) unless $results->rows;

  my $ua = Mojo::UserAgent->new(
      max_redirects      => 10,
      connect_timeout    => 5,
      inactivity_timeout => 10,
      max_connections    => 10000
    );

  my $our_domain  = $command->app->config->{site}{domain};
  my $our_address = $command->app->config->{site}{address};

  while (my $proxy = $results->hash) {
    my ($ip, $port, $country_code, $scheme, $availability, $anonymous) =
      @$proxy{qw/ip port country_code scheme availability anonymous/};

    $ua->proxy->$scheme(qq{http://$ip:$port});

    my $url = Mojo::URL->new(qq{$scheme://$our_domain/check})->query(ip => $our_address);
    my $start_time = time;
    my $tx = $ua->get($url);
    my $stop_time = time;

    unless ($tx->success) {
      my $err = $tx->error;
      $log->error($err->{code} ?
        qq{[checkproxy] $err->{code} response: $err->{message}} :
        qq{[checkproxy] Connection error: $err->{message}});
      update($command->app, $anonymous ? 'true' : 'false', 'null', $proxy);
      next;
    }

    my $answer = $tx->res->json;
    unless ($answer) {
      $log->error(q{[checkproxy] answer is not json});
      next;
    }

    $anonymous     = $answer->{anonymous} ? 'true' : 'false';
    $availability  = int (($stop_time - $start_time) * 1000);

    update($command->app, $anonymous, $availability, $proxy);

    if ((time - $lock_time) > LOCK_TIME) {
      $pg->db->query(q{update locks set updated_at = now() where name = 'checkproxy'});
      $lock_time = time;
    }
  }

  finish($command->app);
}

sub update {
  my ($app, $anonymous, $availability, $proxy) = @_;

  my ($ip, $port, $scheme) = @$proxy{qw/ip port scheme/};

  $app->pg->db->query(qq{
    update proxy
      set anonymous = $anonymous, availability = $availability, updated_at = now()
    where ip = '$ip' and port = $port and scheme = '$scheme'
  });
}

sub finish {
  my $app = shift;
  $app->pg->db->query(q{update locks set lock = false, updated_at = now() where name = 'checkproxy'});
}

1;
