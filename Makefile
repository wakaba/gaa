all: deps

deps: git-submodules pmbp-upgrade pmbp-install

git-submodules:
	git submodule update --init
local/bin/pmbp.pl:
	curl http://wakaba.github.io/packages/pmbp | sh
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl
pmbp-update: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update
pmbp-install: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --install --create-perl-command-shortcut perl
