package GAA::GitHub;
use strict;
use warnings;
use AnyEvent;
use Web::UserAgent::Functions qw(http_get http_post_data);
use JSON::PS;

sub new_from_access_token ($$) {
  return bless {access_token => $_[1]}, $_[0];
} # new_from_access_token

sub host ($) {
  return 'api.github.com';
} # host

sub add_deploy_key_as_cv ($%) {
  my ($self, %args) = @_;
  my $cv = AE::cv;
  my $url = sprintf q<https://%s/repos/%s/%s/keys>,
      $self->host, $args{user}, $args{repo};
  http_post_data
      url => $url,
      header_fields => {Authorization => 'token ' . $self->{access_token}},
      content => perl2json_bytes {
        title => $args{key}->comment,
        key => $args{key}->pub_key,
      },
      anyevent => 1,
      cb => sub {
        $cv->croak ($_[1]->content) unless $_[1]->is_success;
        my $result = json_bytes2perl $_[1]->content;
        $args{key}->rid_path->spew ($result->{id});
        $cv->send;
      };
  return $cv;
} # add_deploy_key_as_cv

sub delete_deploy_key_as_cv ($%) {
  my ($self, %args) = @_;
  my $cv = AE::cv;
  my $url = sprintf q<https://%s/repos/%s/%s/keys/%s>,
      $self->host, $args{user}, $args{repo}, $args{key}->rid_path->slurp;
  http_post_data
      url => $url,
      override_method => 'DELETE',
      header_fields => {Authorization => 'token ' . $self->{access_token}},
      content => '',
      anyevent => 1,
      cb => sub {
        warn $_[1]->content unless $_[1]->is_success;
        $cv->send;
      };
  return $cv;
} # delete_deploy_key_as_cv

1;
