APP_NAME  := ClipboardManager
BUNDLE    := $(APP_NAME).app
SRC_DIR   := Sources
RES_DIR   := Resources
BUILD_DIR := .build

SOURCES := $(sort $(wildcard $(SRC_DIR)/*.swift))
ARCH    := $(shell uname -m)

.PHONY: all build run clean

all: build

build: $(BUNDLE)

$(BUILD_DIR)/$(APP_NAME): $(SOURCES)
	@mkdir -p $(BUILD_DIR)
	swiftc \
		-o $(BUILD_DIR)/$(APP_NAME) \
		-target $(ARCH)-apple-macos12.0 \
		-framework Carbon \
		$(SOURCES)

$(BUNDLE): $(BUILD_DIR)/$(APP_NAME) $(RES_DIR)/AppIcon.icns
	@rm -rf $(BUNDLE)
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	@cp $(RES_DIR)/Info.plist $(BUNDLE)/Contents/
	@cp $(RES_DIR)/AppIcon.icns $(BUNDLE)/Contents/Resources/
	@echo "✅ 构建完成: $(BUNDLE)"

$(RES_DIR)/AppIcon.icns:
	@echo "🎨 生成图标..."
	@python3 gen_icon.py

run: build
	@open $(BUNDLE)

clean:
	@rm -rf $(BUILD_DIR) $(BUNDLE)
	@echo "🧹 清理完成"
