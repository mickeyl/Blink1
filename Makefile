# Build, install and drive the blink(1).
#
# The signal targets play the bank stored inside the device, so they keep running after make exits —
# through sleep, a crashed process or a logout. Run `make bank` once to put the bank in place.

SHELL := /bin/bash

SWIFT ?= swift
CONFIG ?= release
PREFIX ?= /usr/local
BUILD_DIR := .build/$(CONFIG)
BIN := $(BUILD_DIR)/blink1

# make DEVICE=36cf12c4 error   — pick one of several attached blink(1)s
DEVICE ?=
DEVICE_FLAG := $(if $(DEVICE),--device $(DEVICE),)
BLINK1 := $(BIN) $(DEVICE_FLAG)
# make BRIGHTNESS=0.4 bank     — a calmer bank for a desk you sit close to
BRIGHTNESS ?= 1.0
Q := --quiet

.PHONY: help build debug test install uninstall clean list info read map bank bank-save \
        app app-project app-run off ok idle busy info-signal warn error critical success failure \
        host-gone demo

help: ## Show this help
	@echo "Build and inspect:"
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Signals (played by the device itself; \`make bank\` installs them):"
	@grep -hE '^[a-z-]+:.*?#> ' $(MAKEFILE_LIST) | awk -F':.*#> ' '{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Variables: CONFIG=$(CONFIG) PREFIX=$(PREFIX) BRIGHTNESS=$(BRIGHTNESS) DEVICE=$(if $(DEVICE),$(DEVICE),<first found>)"

build: ## Build the release binary
	$(SWIFT) build -c release

debug: ## Build the debug binary
	$(SWIFT) build

test: ## Run the test suite (hardware tests are skipped when nothing is attached)
	$(SWIFT) test

install: build ## Install blink1 into PREFIX/bin
	install -d $(PREFIX)/bin
	install -m 755 .build/release/blink1 $(PREFIX)/bin/blink1

uninstall: ## Remove blink1 from PREFIX/bin
	rm -f $(PREFIX)/bin/blink1

clean: ## Remove build artifacts
	rm -rf .build App/.build App/Blink1Bar.xcodeproj

app-project: ## Regenerate App/Blink1Bar.xcodeproj from App/project.yml
	@App/Scripts/generate-project.sh

app: app-project ## Build the menu bar app
	@xcodebuild -project App/Blink1Bar.xcodeproj -scheme Blink1Bar -configuration Release \
		-destination 'platform=macOS' -derivedDataPath App/.build/DerivedData build | xcbeautify -qq

app-run: app ## Build and launch the menu bar app
	@pkill -f Blink1Bar.app 2>/dev/null || true
	@open App/.build/DerivedData/Build/Products/Release/Blink1Bar.app

$(BIN):
	$(SWIFT) build -c $(CONFIG)

list: $(BIN) ## List attached devices
	@$(BLINK1) list

info: $(BIN) ## Show model, firmware and capabilities
	@$(BLINK1) info

read: $(BIN) ## Print the color currently shown
	@$(BLINK1) read

map: $(BIN) ## Print the slot layout of the signal bank
	@$(BLINK1) bank map

bank: $(BIN) ## Install the signal bank into the device's RAM
	@$(BLINK1) bank install --brightness $(BRIGHTNESS)

bank-save: $(BIN) ## Install the signal bank into flash (replaces the stored pattern for good)
	@$(BLINK1) bank install --brightness $(BRIGHTNESS) --save

off: $(BIN) #> Dark
	@$(BLINK1) signal off $(Q)

ok: $(BIN) #> Steady green — everything is fine
	@$(BLINK1) signal ok $(Q)

idle: $(BIN) #> Dim teal, breathing slowly — powered, nothing to report
	@$(BLINK1) signal idle $(Q)

busy: $(BIN) #> Blue, breathing — something is running
	@$(BLINK1) signal busy $(Q)

info-signal: $(BIN) #> Short cyan blip — something wants to be read
	@$(BLINK1) signal info $(Q)

warn: $(BIN) #> Amber double pulse — needs a look
	@$(BLINK1) signal warn $(Q)

error: $(BIN) #> Fast red double blink — something broke
	@$(BLINK1) signal error $(Q)

critical: $(BIN) #> Red and white strobe — drop everything
	@$(BLINK1) signal critical $(Q)

success: $(BIN) #> Two green flashes, then steady green — finished well
	@$(BLINK1) signal success $(Q)

failure: $(BIN) #> Two red flashes, then steady red — finished badly
	@$(BLINK1) signal failure $(Q)

host-gone: $(BIN) #> Slow dim red heartbeat — what the watchdog falls back to
	@$(BLINK1) signal host-gone $(Q)

demo: bank ## Show every signal for three seconds
	@for signal in idle ok busy info warn error critical success failure host-gone; do \
		printf "  %-10s %s\n" "$$signal" "$$($(BLINK1) bank map | awk -v s=$$signal '$$1 == s {$$1=$$2=$$3=$$4=""; print substr($$0,5)}')"; \
		$(BLINK1) signal $$signal $(Q); \
		sleep 3; \
	done
	@$(BLINK1) signal off $(Q)
