.PHONY: build run clean hooks-install hooks-uninstall verify verify-codex

BUILD_DIR = ./build
SYNC_DIR  = $(HOME)/sync

# build 版本号注入：<commit short hash>[-d].<MMDD-HHMM>
# 关于面板（macOS About）显示「版本 1.0 (fb7f900-d.0504-2318)」；
# -d 后缀标记 working tree 有未 commit 改动，避免误读为该 commit 真值
COMMIT  := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
DIRTY   := $(shell git diff --quiet HEAD -- Glance/ Makefile scripts/ 2>/dev/null && echo "" || echo "-d")
STAMP   := $(shell date +%m%d-%H%M)
VERSION := $(COMMIT)$(DIRTY).$(STAMP)

build:
	xcodebuild -project Glance.xcodeproj -scheme Glance \
		-configuration Debug CONFIGURATION_BUILD_DIR=$(BUILD_DIR) \
		CURRENT_PROJECT_VERSION="$(VERSION)" \
		build
	@touch $(BUILD_DIR)/Glance.app
	@echo "  ✓ touched $(BUILD_DIR)/Glance.app — Finder mtime 同步到当前编译时刻"
	@printf 'commit:       %s\ndirty:        %s\nversion:      %s\ncommit_time:  %s\ncommit_msg:   %s\nbuilt_at:     %s\nhost:         %s\n' \
		"$(COMMIT)" \
		"$$([ -z '$(DIRTY)' ] && echo no || echo yes)" \
		"$(VERSION)" \
		"$$(git log -1 --format=%cI 2>/dev/null || echo unknown)" \
		"$$(git log -1 --format=%s 2>/dev/null || echo unknown)" \
		"$$(date +%FT%T%z)" \
		"$$(hostname)" \
		> $(BUILD_DIR)/Glance.app.BuildInfo.txt
	@echo "  ✓ wrote $(BUILD_DIR)/Glance.app.BuildInfo.txt (version: $(VERSION))"
	@rm -rf $(SYNC_DIR)/Glance.app $(SYNC_DIR)/Glance.app.BuildInfo.txt
	@cp -R $(BUILD_DIR)/Glance.app $(SYNC_DIR)/Glance.app
	@cp $(BUILD_DIR)/Glance.app.BuildInfo.txt $(SYNC_DIR)/Glance.app.BuildInfo.txt
	@echo "  ✓ synced to $(SYNC_DIR)/Glance.app + .BuildInfo.txt"

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
