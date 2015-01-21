use strict;
use warnings;
use Path::Tiny;
use GAA::Server;

my $server = GAA::Server->new;
$server->config ({http_hostname => $ENV{GAA_HTTP_HOSTNAME},
                  http_port => $ENV{GAA_HTTP_PORT} || 6135,
                  logs_path => $ENV{GAA_LOG_DIR}});
$server->run;
