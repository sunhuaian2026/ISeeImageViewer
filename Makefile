.PHONY: build run clean hooks-install hooks-uninstall

BUILD_DIR = ./build

build:
	xcodebuild -project ISeeImageViewer.xcodeproj -scheme ISeeImageViewer \
		-configuration Debug CONFIGURATION_BUILD_DIR=$(BUILD_DIR) build

run: build
	open $(BUILD_DIR)/ISeeImageViewer.app

clean:
	rm -rf $(BUILD_DIR)

hooks-install:
	chmod +x .githooks/pre-push
	git config core.hooksPath .githooks
	@echo "✓ git hooks installed (core.hooksPath=.githooks)"
	@echo "  bypass one push:  git push --no-verify"
	@echo "  bypass via env:   SKIP_CODEX_REVIEW=1 git push"
	@echo "  bypass via msg:   include [skip-codex] or [wip] in a commit message"

hooks-uninstall:
	-git config --unset core.hooksPath
	@echo "✓ git hooks disabled (core.hooksPath unset)"
