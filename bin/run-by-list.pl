use strict;
use warnings;
use Path::Tiny;
local $ENV{LANG} = 'C';

my $run = path (__FILE__)->parent->child ('run-update.sh')->stringify;

while (<>) {
  if (/^\s*#/) {
    #
  } elsif (/^(\S+)\s+(\S+)$/) {
    local $ENV{GAA_GH_USER} = $1;
    local $ENV{GAA_GH_REPO} = $2;
    system 'bash', $run;
  }
}
