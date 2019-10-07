package GAA::Key;
use strict;
use warnings;

sub new_from_host_and_path_and_name ($$$$) {
  return bless {host => $_[1], path => $_[2], name => $_[3]}, $_[0];
} # new_from_host_and_path_and_name

sub secret_path ($) {
  return $_[0]->{secret_path} ||= $_[0]->{path}->child ($_[0]->{name});
} # secret_path

sub pub_path ($) {
  return $_[0]->{pub_path} ||= $_[0]->{path}->child ($_[0]->{name} . '.pub');
} # pub_path

sub rid_path ($) {
  return $_[0]->{rid_path} ||= $_[0]->{path}->child ($_[0]->{name} . '.rid');
} # rid_path

sub comment ($) {
  return $_[0]->{comment} ||= sprintf '%s@GAA.%s:%s',
      $_[0]->{name}, $_[0]->{host}, time;
} # comment

sub has_key ($) {
  return $_[0]->secret_path->is_file;
} # has_key

sub create_key_if_not_found ($) {
  my $self = $_[0];
  unless ($self->has_key) {
    $self->secret_path->parent->mkpath;
    system 'ssh-keygen',
              '-t' => 'rsa',
              '-N' => '',
              '-C' => $self->comment,
              '-f' => $self->secret_path;
  }
} # create_key_if_not_found

sub pub_key ($) {
  my ($self) = @_;
  my $pub = $self->pub_path;
  return undef unless $pub->is_file;
  my $key = $pub->slurp;
  if ($key =~ /^(\S+\s+\S+)/) {
    return $1;
  }
  return undef;
} # pub_key

1;

__END__

http_post_data
    url => q<https://api.github.com/authorizations>,
    content => perl2json_bytes {
      scopes => ['repo'],
      note => 'test1',
    },
    basic_auth => [$args{user}, $args{password}];
