.PHONY: all build install release clean test

all: build

build:
	@chmod +x scripts/build.sh
	@./scripts/build.sh

install: build
	@echo "==> Installing to /Applications/Default App.app..."
	@killall -9 DefaultApp 2>/dev/null || true
	@rm -rf "/Applications/Default App.app"
	@cp -R "build/Default App.app" "/Applications/Default App.app"
	@codesign -fs - --deep "/Applications/Default App.app"
	@touch "/Applications/Default App.app"
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/Default App.app"
	@echo "==> Installed successfully! Run with 'open /Applications/Default\\ App.app'"

release:
	@chmod +x scripts/build.sh scripts/package_release.sh
	@./scripts/package_release.sh

clean:
	@echo "==> Cleaning build artifacts..."
	@rm -rf build/ dist/ /tmp/default_app_build /tmp/default_app_dmg
