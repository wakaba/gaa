use strict;
use warnings;
use Path::Tiny;
use lib path (__FILE__)->parent->parent->child ('lib')->stringify;
use MIME::Base64 qw(decode_base64);
use GAA::Key;
use GAA::GitHub;

my ($keys_dir, $host, $user, $repo) = @ARGV;
die "Usage: $0 host user repo\n"
    unless defined $repo and
        $host =~ /\A[A-Za-z0-9_.-]+\z/ and
        $user =~ /\A[A-Za-z0-9_.-]+\z/ and
        $repo =~ /\A[A-Za-z0-9_.-]+\z/;
my $keys_path = path $keys_dir;

my $key = GAA::Key->new_from_host_and_path_and_name
    ($host, $keys_path, "$user/$repo");
my $gh = GAA::GitHub->new_from_access_token
    (decode_base64 $keys_path->child ('.access_token')->slurp);

if ($key->rid_path->is_file) {
  $gh->delete_deploy_key_as_cv (user => $user, repo => $repo, key => $key)
      ->recv;
}
