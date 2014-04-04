#!/bin/sh
reposdir=${GAA_REPOS_DIR:-repos}
keysdir=${GAA_KEYS_DIR:-keys}
logdir=${GAA_LOG_DIR:-logs}
hostname=${GAA_HOST_NAME:-gaahost}
ghuser=${GAA_GH_USER:-@@@}
ghrepo=${GAA_GH_REPO:-@@@}

mkdir -p $logdir/$ghuser
exec > $logdir/$ghuser/$ghrepo.txt 2>&1

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
    (git checkout -b nightly origin/nightly || git checkout -b nightly) && \
    timeout -s KILL 600 make deps && \
    timeout -s KILL 7200 make updatenightly && \
    git commit -m auto && \
    git push origin nightly

status=$?
if [ $status -ne 0 ]; then
  echo "XXX failed"
fi
