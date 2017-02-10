package Test::CheckProxy;
use Mojo::Base 'Test::Mojo';

use Test::Mojo;
use Mojolicious::Commands;

sub new {
  my $class = shift;

  $ENV{MOJO_MODE} //= 'test';

  my $self = $class->SUPER::new(shift)->tap(
    sub {
      $_->ua->max_connections(0);
      my $pg = $_->app->pg;
      my $result = $pg->db->query(q{select tablename from pg_tables where schemaname = 'public'});
      while (my $table = $result->array) {
        next if $table->[0] eq 'mojo_migrations' or $table->[0] eq 'locks';
        $pg->db->do(qq{truncate table ${$table}[0] cascade});
      }
    }
  );

  return $self;
}

1;
