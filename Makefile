.PHONY: build run clean hooks-install hooks-uninstall verify verify-codex

BUILD_DIR = ./build
SYNC_DIR  = $(HOME)/sync

build:
	xcodebuild -project Glance.xcodeproj -scheme Glance \
		-configuration Debug CONFIGURATION_BUILD_DIR=$(BUILD_DIR) build
	@touch $(BUILD_DIR)/Glance.app
	@echo "  ✓ touched $(BUILD_DIR)/Glance.app — Finder mtime 同步到当前编译时刻"
	@rm -rf $(SYNC_DIR)/Glance.app
	@cp -R $(BUILD_DIR)/Glance.app $(SYNC_DIR)/Glance.app
	@echo "  ✓ synced to $(SYNC_DIR)/Glance.app"

run: build
	open $(BUILD_DIR)/Glance.app

clean:
	rm -rf $(BUILD_DIR)

hooks-install:
	chmod +x .githooks/pre-push scripts/verify.sh
	git config core.hooksPath .githooks
	@echo "✓ git hooks installed (core.hooksPath=.githooks)"
	@echo "  bypass one push:  git push --no-verify"
	@echo "  bypass via env:   SKIP_CODEX_REVIEW=1 git push"
	@echo "  bypass via msg:   include [skip-codex] or [wip] in a commit message"

hooks-uninstall:
	-git config --unset core.hooksPath
	@echo "✓ git hooks disabled (core.hooksPath unset)"

verify:
	@chmod +x scripts/verify.sh 2>/dev/null || true
	@./scripts/verify.sh

verify-codex:
	@chmod +x scripts/verify.sh 2>/dev/null || true
	@./scripts/verify.sh --with-codex
