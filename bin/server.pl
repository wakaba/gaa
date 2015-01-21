use strict;
use warnings;
use Path::Tiny;
use GAA::Server;

my $server = GAA::Server->new;
$server->config ({http_port => 6135});
$server->run;
