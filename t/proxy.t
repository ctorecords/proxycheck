use Mojo::Base -strict;

use Test::More;
use Test::CheckProxy;

my $t = Test::CheckProxy->new('CheckProxy');

my $pg = $t->app->pg;

# ip            varchar(15) NOT NULL,
# port          integer NOT NULL check (port > 0),
# country_code   char(2) NOT NULL check (country_code = upper (country_code)),
# scheme        varchar(5) NOT NULL,
# availability  integer check (availability >= 0) default null,
# anonymous     boolean default false,
# 

$pg->db->query(q{insert into proxy values ('127.0.0.1', 123, 'RU', 'https')});
$pg->db->query(q{insert into proxy values ('127.0.0.2', 123, 'RU', 'https', 123)});
$pg->db->query(q{insert into proxy values ('127.0.0.3', 122, 'RU', 'https', 122)});
$pg->db->query(q{insert into proxy values ('127.0.0.4', 126, 'RU', 'https', 126)});
$pg->db->query(q{insert into proxy values ('127.0.0.5', 127, 'RU', 'http', 127)});

$pg->db->query(q{insert into proxy values ('127.0.0.5', 126, 'EN', 'http', 126)});
$pg->db->query(q{insert into proxy values ('127.0.0.6', 127, 'EN', 'http', 127)});
$pg->db->query(q{insert into proxy values ('127.0.0.7', 123, 'EN', 'http', 123, true)});
$pg->db->query(q{insert into proxy values ('127.0.0.8', 125, 'EN', 'http', 125)});
$pg->db->query(q{insert into proxy values ('127.0.0.9', 129, 'EN', 'https', 129)});

$pg->db->query(q{insert into proxy values ('127.0.1.5', 126, 'UK', 'http', 126)});

$t->get_ok('/proxylist')->status_is(200)->json_is({
    'RU' => {
      https => [
        {ip => '127.0.0.3', port => 122, type => 'https', availability => 122, anonymous => 0, country_code => 'RU'},
        {ip => '127.0.0.2', port => 123, type => 'https', availability => 123, anonymous => 0, country_code => 'RU'},
        {ip => '127.0.0.4', port => 126, type => 'https', availability => 126, anonymous => 0, country_code => 'RU'}
      ],
      http => [
        {ip => '127.0.0.5', port => 127, type => 'http', availability => 127, anonymous => 0, country_code => 'RU'}
      ]
    },
    'EN' => {
      http => [
        {ip => '127.0.0.8', port => 125, type => 'http', availability => 125, anonymous => 0, country_code => 'EN'},
        {ip => '127.0.0.5', port => 126, type => 'http', availability => 126, anonymous => 0, country_code => 'EN'},
        {ip => '127.0.0.6', port => 127, type => 'http', availability => 127, anonymous => 0, country_code => 'EN'},
        {ip => '127.0.0.7', port => 123, type => 'http', availability => 123, anonymous => 1, country_code => 'EN'}
      ],
      https => [
        {ip => '127.0.0.9', port => 129, type => 'https', availability => 129, anonymous => 0, country_code => 'EN'}
      ]
    }
  });

done_testing;

__END__

{
            'RU' => {
                'http' => [
                            {
                              'port' => '3128',
                              'country_code' => 'RU',
                              'type' => 'http',
                              'ip' => '85.234.22.126'
                            },
                            {
                              'country_code' => 'RU',
                              'type' => 'http',
                              'ip' => '94.228.205.33',
                              'port' => '8080'
                            },
                            {
                              'type' => 'http',
                              'ip' => '178.46.135.76',
                              'country_code' => 'RU',
                              'port' => '8080'
                            },
                            {
                              'ip' => '78.109.137.225',
                              'type' => 'http',
                              'country_code' => 'RU',
                              'port' => '3128'
                            },
                            {
                              'port' => '8080',
                              'type' => 'http',
                              'ip' => '78.29.24.74',
                              'country_code' => 'RU'
                            },
                            {
                              'port' => '85',
                              'country_code' => 'RU',
                              'ip' => '176.62.84.62',
                              'type' => 'http'
                            },
                            {
                              'port' => '9090',
                              'ip' => '85.236.25.21',
                              'type' => 'http',
                              'country_code' => 'RU'
                            },
                            {
                              'country_code' => 'RU',
                              'type' => 'http',
                              'ip' => '85.113.33.197',
                              'port' => '8080'
                            }
                          ],
                'https' => [
                             {
                               'country_code' => 'RU',
                               'ip' => '176.109.0.13',
                               'type' => 'https',
                               'port' => '8080'
                             },
                             {
                               'port' => '80',
                               'country_code' => 'RU',
                               'ip' => '89.232.139.253',
                               'type' => 'https'
                             },
                             {
                               'port' => '3128',
                               'country_code' => 'RU',
                               'ip' => '195.62.79.238',
                               'type' => 'https'
                             }
                           ]
              }
          }
