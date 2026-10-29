PREFIX ?= $(HOME)/.local
SHELL_FILES = bin/claude-profiles install.sh test/helpers/common.bash

.PHONY: help test lint install uninstall

help:
	@echo "make test       run the test suite (needs bats-core: brew install bats-core)"
	@echo "make lint       shellcheck all shell code"
	@echo "make install    install to $(PREFIX)"
	@echo "make uninstall  remove the tool from $(PREFIX) (profiles are kept)"

test:
	bats test/

lint:
	shellcheck -s bash $(SHELL_FILES)
	@tmp=$$(mktemp -d) && HOME="$$tmp" XDG_CONFIG_HOME="$$tmp/c" CLAUDE_PROFILES_APPS_DIR="$$tmp/a" \
	  CLAUDE_PROFILES_BIN_DIR="$$tmp/b" CLAUDE_APP=/System/Applications/Calculator.app \
	  bin/claude-profiles add lint >/dev/null 2>&1 && \
	  shellcheck -s bash "$$tmp/a/Claude Lint.app/Contents/Resources/launch.sh" && \
	  shellcheck -s sh "$$tmp/b/claude-lint"; status=$$?; rm -rf "$$tmp"; exit $$status

install:
	CLAUDE_PROFILES_PREFIX="$(PREFIX)" ./install.sh

uninstall:
	CLAUDE_PROFILES_PREFIX="$(PREFIX)" ./install.sh --uninstall
