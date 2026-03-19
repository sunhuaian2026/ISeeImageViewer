BUILD_DIR = ./build

build:
	xcodebuild -project ISeeImageViewer.xcodeproj -scheme ISeeImageViewer \
		-configuration Debug CONFIGURATION_BUILD_DIR=$(BUILD_DIR) build

run: build
	open $(BUILD_DIR)/ISeeImageViewer.app

clean:
	rm -rf $(BUILD_DIR)
