all: deps

updatenightly: local/bin/pmbp.pl
	curl https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	git add modules
	perl local/bin/pmbp.pl --update
	git add config lib/

deps: git-submodules pmbp-upgrade pmbp-install

PMBP_OPTIONS = 

git-submodules:
	git submodule update --init
local/bin/pmbp.pl:
	curl -s -S -L http://wakaba.github.io/packages/pmbp | sh
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update-pmbp-pl
pmbp-update: local/bin/pmbp.pl
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update
pmbp-install: local/bin/pmbp.pl
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --install \
	    --create-perl-command-shortcut @perl \
	    --create-perl-command-shortcut @prove

PROVE = ./prove

test: test-deps test-main
test-deps: deps
test-main:
	$(PROVE) t/