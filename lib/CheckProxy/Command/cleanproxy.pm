package CheckProxy::Command::cleanproxy;
use Mojo::Base 'Mojolicious::Command';

has description => 'Cleaning not working proxy.';
has usage       => "Usage: perl script/listee cleanproxy\n";

sub run {
  my $command = shift;

  my $pg  = $command->app->pg;
  my $log = $command->app->log;

  my $results = $pg->db->query(q{
    select *
    from proxy
    where updated_at - last_available > interval '5 days'
  });

  my $proxies = $results->hashes;

  $proxies->each(sub {
    my $proxy = shift;

    $pg->db->query(q{
      delete from proxy
      where ip = ? and port = ? and scheme = ?
    }, $proxy->{ip}, $proxy->{port}, $proxy->{scheme});
  });
}

1;
