package CheckProxy;
use Mojo::Base 'Mojolicious';

use Minion;
use Mojo::Pg;
use CheckProxy::Task::checkproxy;

# This method will run once at server start
sub startup {
  my $app = shift;

  # Documentation browser under "/perldoc"
  # $app->plugin('PODRenderer');

  my $mode = $app->mode;
  $app->secrets(['HfME55B9T1FbVJSZ4Jqs']);
  $app->sessions->cookie_name('check_proxy');

  push @{$app->commands->namespaces}, 'CheckProxy::Command';

  $app->plugin('Config', file => "checkproxy.$mode.conf");
  $app->plugin(Minion => {Pg => $app->config->{pg}{uri}});
  #$app->plugin(Minion => {File => '/tmp/minion2.db'});

  $app->helper(pg => sub { state $pg = Mojo::Pg->new($app->config->{pg}{uri}) });

  $app->minion->add_task(checkproxy => sub { CheckProxy::Task::checkproxy->new->run(@_) });

  # Router
  my $r = $app->routes;

  # Normal route to controller
  $r->get('/check')->to('check#anonymous');
  $r->get('/proxylist')->to('proxy#list');

  $app->initialize;
}

sub initialize {
  my $app = shift;

  my $pg = $app->pg;
  $pg->migrations->name('checkproxy')->from_data->migrate;
}

1;

__DATA__

@@ checkproxy
-- 6 up
alter table proxy add column id uuid primary key default gen_random_uuid();
alter table proxy add column created timestamp default now();

alter table proxy drop column if exists updated_at;
alter table proxy drop column if exists last_available;
alter table proxy drop column if exists availability;

-- 5 up
create table if not exists proxy (
  ip              varchar(15) NOT NULL,
  port            integer     NOT NULL check (port > 0),
  country_code    char(2)     NOT NULL check (country_code = upper (country_code)),
  scheme          varchar(5)  NOT NULL check (scheme = any(array['http', 'https'])),
  availability    integer     check (availability >= 0) default null,
  anonymous       boolean     default false,
  last_available  timestamp   default now(),
  updated_at      timestamp   default null,
  unique          (ip, port, scheme)
);
create index on proxy (availability, anonymous);

-- 1 down
drop table proxy;
