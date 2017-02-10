package CheckProxy::Controller::Check;
use Mojo::Base 'Mojolicious::Controller';

sub anonymous {
  my $c = shift;

  my $headers = $c->req->headers;
  my $headers_name = $headers->names;

  my $ipaddress = $c->param('ip');

  my $is_anonymous = 1;
  for (@$headers_name) {
    next if 'host' eq lc;

    my $value = $headers->header($_);
    $is_anonymous = 0 if index($value, $ipaddress) >= 0;
  }

  $c->render(json => {anonymous => $is_anonymous});
}

1;
