package CheckProxy::Command::proxy_to_worker;
use Mojo::Base 'Mojolicious::Command';

use Mojo::UserAgent;
use Time::HiRes 'time';

use constant LOCK_TIME => 5 * 60;
use constant PROXY_PACK => 30;

has description => "Check proxy.";
has usage       => "Usage: perl script/listee proxy_to_worker\n";

sub run {
  my $command = shift;

  my $pg      = $command->app->pg;
  my $log     = $command->app->log;
  my $minion  = $command->app->minion;

  my $pack = [];
  my $count = 0;

  my $not_checked_yet = $pg->db->query(q{
    select * from proxy
    where updated_at is null
  });

  while (my $proxy = $not_checked_yet->hash) {
    push @$pack, $proxy;
    ++$count;

    if ($count == PROXY_PACK) {
      $command->app->minion->enqueue(checkproxy => $pack);
      ($pack, $count) = ([], 0);
    }
  }

  my $already_checked = $pg->db->query(q{
    select * from proxy
    where updated_at is not null
    order by updated_at asc
  });

  while (my $proxy = $already_checked->hash) {
    push @$pack, $proxy;
    ++$count;

    if ($count == PROXY_PACK) {
      $command->app->minion->enqueue(checkproxy => $pack);
      ($pack, $count) = ([], 0);
    }
  }

  $command->app->minion->enqueue(checkproxy => $pack) if $count;
}

1;
