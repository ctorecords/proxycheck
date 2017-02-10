package CheckProxy::Controller::Proxy;
use Mojo::Base 'Mojolicious::Controller';

sub list {
  my $c = shift;

  my $bnrs_user = $c->req->headers->header('X-BNRS-REAL-USER') // $c->req->headers->header('X-BNRS-USER');

  my $proxyhash = {};

  my $results = $c->pg->db->query(q{
    select * from (
      select *, row_number() over (partition by country_code, scheme), count(*) over (partition by country_code, scheme)
      from proxy
      where country_code is not null and country_code != ''
    ) as grouped where grouped.row_number <= 30 and grouped.count >= 2
  });

  if ($results->rows) {
    while (my $proxy = $results->hash) {
      my ($ip, $port, $country_code, $scheme) = @$proxy{qw/ip port country_code scheme/};

      push @{$proxyhash->{$country_code}{$scheme}}, {
        ip    => $ip,
        port  => $port,
        type  => $scheme,
        country_code => $country_code
      };
    }

    for my $country_code (keys %$proxyhash) {
      delete $proxyhash->{$country_code} unless $proxyhash->{$country_code}{http} && $proxyhash->{$country_code}{https};
    }
  }

  $results = $c->pg->db->query(q{
    select * from (
      select *, row_number() over (partition by scheme)
      from proxy
    ) as grouped
    where grouped.row_number <= 100
  });

  if ($results->rows) {
    while (my $proxy = $results->hash) {
      my ($ip, $port, $country_code, $scheme) = @$proxy{qw/ip port country_code scheme/};

      push @{$proxyhash->{ANY}{$scheme}}, {
        ip    => $ip,
        port  => $port,
        type  => $scheme,
        country_code => $country_code
      };
    }
  }

  $c->render(json => $proxyhash);
}

sub list_backup {
  my $c = shift;

  my $bnrs_user = $c->req->headers->header('X-BNRS-REAL-USER') // $c->req->headers->header('X-BNRS-USER');

  my $proxyhash = {};

  my $results = $c->pg->db->query(q{
    select * from (
      select *, row_number() over (partition by country_code, scheme order by availability), count(*) over (partition by country_code, scheme)
      from proxy
      where availability is not null and anonymous = true
    ) as sorted where sorted.row_number <= 30 and sorted.count >= 7
  });

  if ($results->rows) {
    while (my $proxy = $results->hash) {
      my ($ip, $port, $country_code, $scheme, $availability, $anonymous) =
        @$proxy{qw/ip port country_code scheme availability anonymous/};

      push @{$proxyhash->{$country_code}{$scheme}}, {
        ip => $ip, port => $port, type => $scheme, country_code => $country_code,
        availability => $availability, anonymous => $anonymous
      };
    }

    for my $country_code (keys %$proxyhash) {
      delete $proxyhash->{$country_code} unless $proxyhash->{$country_code}{http} && $proxyhash->{$country_code}{https};
    }
  }

  $results = $c->pg->db->query(q{
    select * from (
      select *, row_number() over (partition by scheme order by availability)
      from proxy
      where availability is not null and anonymous = true
    ) as sorted
    where sorted.row_number <= 80
  });

  if ($results->rows) {
    while (my $proxy = $results->hash) {
      my ($ip, $port, $country_code, $scheme, $availability, $anonymous) =
        @$proxy{qw/ip port country_code scheme availability anonymous/};

      push @{$proxyhash->{ANY}{$scheme}}, {
        ip => $ip, port => $port, type => $scheme, country_code => $country_code,
        availability => $availability, anonymous => $anonymous
      };
    }
  }

  $c->render(json => $proxyhash);
}

1;
