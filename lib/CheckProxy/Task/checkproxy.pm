package CheckProxy::Task::checkproxy;
use Mojo::Base -base;

use Mojo::IOLoop;
use Mojo::UserAgent;
use Time::HiRes 'time';

sub run {
  my ($self, $job, @proxylist) = @_;

  my $app = $job->app;
  my $log = $app->log;

  my $our_domain  = $job->app->config->{site}{domain};
  my $our_address = $job->app->config->{site}{address};

  my $delay = Mojo::IOLoop->delay;

  for my $proxy (@proxylist) {
    next unless $proxy;
    my ($ip, $port, $country_code, $scheme, $availability, $anonymous) =
      @$proxy{qw/ip port country_code scheme availability anonymous/};

    my $ua = Mojo::UserAgent->new(
      max_redirects      => 20,
      connect_timeout    => 5,
      inactivity_timeout => 10,
      max_connections    => 10000
    );

    #31.13.198.251:8080
    #61.184.192.42:80

    $ua->proxy->$scheme(qq{http://$ip:$port});

    my $end = $delay->begin;

    my $url = Mojo::URL->new(qq{$scheme://$our_domain/check})->query(ip => $our_address);

    my $start_time = time;

    $ua->get($url => sub {
      $ua //= undef;

      my $stop_time = time;

      shift;
      my $tx = shift;

      unless ($tx->success) {
        my $err = $tx->error;
        # $log->error($err->{code} ?
        #   qq{[task checkproxy] $err->{code} response: $err->{message}} :
        #   qq{[task checkproxy] Connection error: $err->{message}});
        update($app, $anonymous, undef, $proxy);
        return $end->();
      }

      my $answer = $tx->success->json;
      unless ($answer) {
        $log->error(q{[task checkproxy] answer is not json:}, "ipaddr - $ip:$port:$scheme", "query - $url", $app->dumper($tx->res->body));
        update($app, $anonymous, undef, $proxy);
        return $end->();
      }

      if (ref $answer ne 'HASH') {
        $log->error('[task checkproxy] answer not hash:', "ipaddr - $ip:$port:$scheme", "query - $url", $app->dumper($answer));
        update($app, $anonymous, undef, $proxy);
        return $end->();
      }

      unless (exists $answer->{anonymous}) {
        $log->error('[task checkproxy] answer not have key anonymous:', "ipaddr - $ip:$port:$scheme", "query - $url", $app->dumper($answer));
        update($app, $anonymous, undef, $proxy);
        return $end->();
      }

      $availability  = int (($stop_time - $start_time) * 1000);
      update($app, $answer->{anonymous}, $availability, $proxy);

      $end->();
    });
  }

  $delay->wait;
  $job->finish;
}

sub update {
  my ($app, $anonymous, $availability, $proxy) = @_;

  my $last_available = '';
  $last_available = ', last_available = now()' if $availability;

  $availability //= 'null';
  $anonymous = $anonymous ? 'true' : 'false';

  my ($ip, $port, $scheme) = @$proxy{qw/ip port scheme/};
  $app->pg->db->query(qq{
    update proxy
      set anonymous = $anonymous, availability = $availability, updated_at = now() $last_available
    where ip = '$ip' and port = $port and scheme = '$scheme'
  });
}

1;
