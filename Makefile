SHELL=/usr/bin/env bash
NAMESPACE ?= default

hooks-install:
	-rm .git/hooks/pre-commit
	(cd .git/hooks/ && ln -s ../../scripts/pre-commit pre-commit)
