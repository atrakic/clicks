MAKEFLAGS += --silent

BASEDIR=$(shell git rev-parse --show-toplevel)

.PHONY: all clean

all:
	$(BASEDIR)/scripts/configure.sh
	$(BASEDIR)/scripts/deploy.sh
	$(BASEDIR)/scripts/backup.sh
	$(BASEDIR)/scripts/test.sh

restore update backup test deploy:
	$(BASEDIR)/scripts/$@.sh

infra:
	pushd $(BASEDIR)/infra; make; popd

clean:
	$(BASEDIR)/scripts/clean.sh
	pushd $(BASEDIR)/infra; make clean; popd
