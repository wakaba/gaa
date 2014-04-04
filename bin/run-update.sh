#!/bin/sh
reposdir=${GAA_REPOS_DIR:-repos}
keysdir=${GAA_KEYS_DIR:-keys}
logdir=${GAA_LOG_DIR:-logs}
hostname=${GAA_HOST_NAME:-gaahost}
ghuser=${GAA_GH_USER:-@@@}
ghrepo=${GAA_GH_REPO:-@@@}
irc_channel=${GAA_IRC_CHANNEL:-#gaa-test}
failure_log_url=${GAA_FAILURE_LOG_URL:-http://test/}
irc_post_url=${GAA_IRC_POST_URL:=http://test/}

mkdir -p $logdir/$ghuser
exec > $logdir/$ghuser/$ghrepo.txt 2>&1

date

gaadir=`dirname $0`/..
gaadir=`cd $gaadir && pwd`
giturl=git@github.com:$ghuser/$ghrepo

repodir=$reposdir/github/$ghuser/$ghrepo
rm -fr $repodir

export HOME=$keysdir
git config --file $keysdir/.gitconfig user.name gaa
git config --file $keysdir/.gitconfig user.email gaa@$hostname

$gaadir/perl $gaadir/bin/add-pubkey.pl $keysdir $hostname $ghuser $ghrepo
export GIT_SSH=$gaadir/bin/ssh_wrapper
key=$keysdir/$ghuser/$ghrepo
export GAA_SSH_PUB_KEY=$key
chmod 0600 $key

git clone $giturl $repodir
cd $repodir && \
    git checkout -b nightly && \
    timeout -s KILL 3600 make deps && \
    timeout -s KILL 10000 make updatenightly && \
    git commit -m auto && \
    git push origin +nightly

status=$?
if [ $status -ne 0 ]; then
  curl --request POST -F channel="$irc_channel" \
      -F message="gaa failed: $failure_log_url$ghuser/$ghrepo.txt" \
      "$irc_post_url"
fi

date
