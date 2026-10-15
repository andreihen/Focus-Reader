TOOLS_DIR ?= /workspace/.focus-reader-tools-2026.07.1
LUAJIT ?= $(TOOLS_DIR)/lib/koreader/luajit
.PHONY: setup test unit integration package
setup:
	FOCUS_TOOLS_DIR="$(TOOLS_DIR)" ./scripts/setup_cloud.sh
unit:
	$(LUAJIT) tests/unit.lua .
integration:
	FOCUS_TOOLS_DIR="$(TOOLS_DIR)" ./scripts/test_integration.sh
test: unit integration
package:
	FOCUS_TOOLS_DIR="$(TOOLS_DIR)" python3 scripts/package.py
