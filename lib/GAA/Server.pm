package GAA::Server;
use strict;
use warnings;
use Path::Tiny;
use Encode;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::HTTPD;
use AnyEvent::Util qw(run_cmd);
use JSON::PS;

my $RunPath = path (__FILE__)->parent->parent->parent->child ('bin/run-update.sh');

sub new ($) {
  return bless {queue => []}, $_[0];
} # new

sub config ($;$) {
  if (@_ > 1) {
    $_[0]->{config} = $_[1];
  }
  return $_[0]->{config} || {};
} # config

sub enqueue ($$) {
  my ($self, $item) = @_;
  $item->{priority} = 0+($item->{priority} || 0);
  $item->{timestamp} = time;
  $item->{key} = $item->{gh_user} . '-' . $item->{gh_repo};
  my $item_to_priority = {};
  my $found = {};

  $self->{queue} = [grep {
    not $found->{$_->{key}}++;
  } sort {
    $b->{priority} <=> $a->{priority} ||
    $a->{timestamp} <=> $b->{timestamp};
  } map {
    $_->{priority} = $item_to_priority->{$_->{key}};
    $_;
  } map {
    $item_to_priority->{$_->{key}} ||= $_->{priority};
    $item_to_priority->{$_->{key}} = $_->{priority}
        if $item_to_priority->{$_->{key}} < $_->{priority};
    $_;
  } @{$self->{queue}}, $item];

  $self->_schedule_to_run_task;
} # enqueue

sub _schedule_to_run_task ($) {
  my $self = $_[0];
  AE::postpone { $self->_run_task };
} # _schedule_to_run_task

sub _run_task ($) {
  my $self = $_[0];
  return if $self->{shutdown} or $self->{running} or not @{$self->{queue}};

  $self->{running} = my $item = shift @{$self->{queue}};
  $item->{status} = 'running';
  $self->log (sprintf 'Run %s/%s...', $item->{gh_user}, $item->{gh_repo});

  my $cv;
  {
    local $ENV{LANG} = 'C';
    local $ENV{TZ} = 'UTC';
    local $ENV{GAA_GH_USER} = $item->{gh_user};
    local $ENV{GAA_GH_REPO} = $item->{gh_repo};
    $cv = (run_cmd [$RunPath], '<' => \'');
  }

  $cv->cb (sub {
    my $result = $_[0]->recv;
    my $item = delete $self->{running};
    $self->log (sprintf '%s/%s done (result %d)',
                    $item->{gh_user}, $item->{gh_repo}, $result >> 8);
    $self->_schedule_to_run_task;
  });
} # _run_task

sub _http ($) {
  my $self = shift;
  my $hostname = $self->config->{http_hostname} // '127.0.0.1';
  my $port = $self->config->{http_port} or die "|http_port| not specified";

  $self->{httpd} = AnyEvent::HTTPD->new
      (hostname => $hostname, port => $port);
  $self->log (sprintf 'Listening %s:%d...', $hostname, $port);

  $self->{httpd}->reg_cb ('' => sub {
    my ($httpd, $req) = @_;
    $self->log (sprintf '%s %s %s', $req->client_host, $req->method, $req->url);
    my $path = $req->url->path;

    if ($path eq '/queue') {
      if ($req->method eq 'POST') {
        return $req->respond ([400, 'Bad origin', {}, '400 Bad origin'])
            if defined $req->headers->{origin};
        my $gh_user = $req->parm ('gh_user')
            // return $req->respond ([400, 'Bad |gh_user|', {}, '400 Bad |gh_user|']);
        my $gh_repo = $req->parm ('gh_repo')
            // return $req->respond ([400, 'Bad |gh_repo|', {}, '400 Bad |gh_repo|']);
        my $priority = $req->parm ('priority');
        $self->enqueue ({gh_user => $gh_user, gh_repo => $gh_repo,
                         priority => $priority});
        return $req->respond ([200, 'Accepted', {}, '200 Accepted']);
      } else {
        my $json = perl2json_bytes [map {
          +{gh_user => $_->{gh_user},
            gh_repo => $_->{gh_repo},
            priority => $_->{priority},
            status => $_->{status} // 'waiting',
            timestamp => $_->{timestamp}};
        } ($self->{running} // ()), @{$self->{queue}}];
        return $req->respond ([200, 'OK', {
          'Content-Type' => 'application/json',
        }, $json]);
      }
    }

    return $req->respond ([404, 'Not found', {}, '404 not found']);
  });
} # _http

sub run_as_cv ($) {
  my $self = shift;
  $self->_http;

  my $cv = AE::cv;

  $self->{sigterm} = AE::signal TERM => sub {
    $self->log ('SIGTERM received', class => 'error');
    $self->shutdown;
    $cv->send;
  };
  $self->{sigint} = AE::signal INT => sub {
    $self->log ('SIGINT received', class => 'error');
    $self->shutdown;
    $cv->send;
  };

  return $cv;
} # run_as_cv

sub shutdown ($) {
  my $self = $_[0];
  $self->{shutdown} = 1;
  $self->{queue} = [];
  delete $self->{httpd};
  delete $self->{sigterm};
  delete $self->{sigint};
} # shutdown

sub run ($) {
  my $cv = $_[0]->run_as_cv;
  $cv->recv;
} # run

sub _stderr () {
  return $_[0]->{stderr} ||= AnyEvent::Handle->new
      (fh => \*STDERR,
       on_error => sub {
         my ($hdl, $fatal, $msg) = @_;
         AE::log error => $msg;
         $hdl->destroy;
         #$cv->send;
       });
} # _stderr

sub log ($$;%) {
  my ($self, $text, %args) = @_;
  my $name = $self->config->{name};
  $self->_stderr->push_write (encode 'utf-8', ('[' . (gmtime) . '] ' . (defined $name ? "$name " : '') . $text . "\n"));
} # log

1;
