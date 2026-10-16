.PHONY: all run clean install

all:
	@chmod +x build.sh
	@./build.sh

run: all
	@echo "==> Launching ChillScreen.app..."
	@killall ChillScreen 2>/dev/null || true
	@open build/ChillScreen.app

clean:
	@rm -rf build

install: all
	@echo "==> Installing to /Applications..."
	@cp -R build/ChillScreen.app /Applications/
	@echo "==> ChillScreen installed to /Applications/ChillScreen.app"
