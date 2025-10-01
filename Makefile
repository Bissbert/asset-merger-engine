# Makefile for asset-merger-engine
# POSIX-compliant Makefile for installation and management

# Variables
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib/asset-merger-engine
ETCDIR = /etc/asset-merger-engine
VARDIR = /var/lib/asset-merger-engine
LOGDIR = /var/log/asset-merger-engine

# Installation user and group
INSTALL_USER ?= root
INSTALL_GROUP ?= root

# Commands
INSTALL = install
MKDIR = mkdir -p
RM = rm -f
RMDIR = rm -rf
CHMOD = chmod
CHOWN = chown

# Default target
.PHONY: all
all: help

# Display help
.PHONY: help
help:
	@echo "Asset Merger Engine Installation"
	@echo "=================================="
	@echo ""
	@echo "Targets:"
	@echo "  install       Install the merger tool (requires root)"
	@echo "  user-install  Install for current user only (no root needed)"
	@echo "  dev-install   Install development symlink (no root needed)"
	@echo "  uninstall     Remove the merger tool"
	@echo "  test          Run tests"
	@echo "  check         Check dependencies"
	@echo "  clean         Clean temporary files"
	@echo "  help          Display this help"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX        Installation prefix (default: /usr/local)"
	@echo "  INSTALL_USER  Installation user (default: root)"
	@echo "  INSTALL_GROUP Installation group (default: root)"
	@echo ""
	@echo "Examples:"
	@echo "  make user-install  # Install for current user"
	@echo "  make dev-install   # Development installation"
	@echo "  sudo make install  # System-wide installation"
	@echo "  make check         # Check dependencies"

# Check dependencies
.PHONY: check
check:
	@echo "Checking dependencies..."
	@command -v sh >/dev/null 2>&1 || { echo "Error: sh not found"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "Warning: jq not found"; }
	@command -v zbx >/dev/null 2>&1 || { echo "Warning: zbx not found"; }
	@command -v topdesk >/dev/null 2>&1 || { echo "Warning: topdesk not found"; }
	@echo "Dependency check complete"

# Install the tool
.PHONY: install
install: check
	@echo "Installing asset-merger-engine..."

	# Create directories
	$(MKDIR) $(BINDIR)
	$(MKDIR) $(LIBDIR)
	$(MKDIR) $(ETCDIR)
	$(MKDIR) $(VARDIR)
	$(MKDIR) $(VARDIR)/cache
	$(MKDIR) $(VARDIR)/output
	$(MKDIR) $(VARDIR)/output/processed
	$(MKDIR) $(VARDIR)/output/failed
	$(MKDIR) $(VARDIR)/output/reports
	$(MKDIR) $(VARDIR)/tmp
	$(MKDIR) $(LOGDIR)

	# Install scripts
	$(INSTALL) -m 755 bin/merger.sh $(BINDIR)/asset-merger-engine

	# Install libraries
	$(INSTALL) -m 644 lib/common.sh $(LIBDIR)/
	$(INSTALL) -m 644 lib/zabbix.sh $(LIBDIR)/
	$(INSTALL) -m 644 lib/topdesk.sh $(LIBDIR)/

	# Install configuration
	@if [ ! -f $(ETCDIR)/merger.conf ]; then \
		$(INSTALL) -m 640 etc/merger.conf.sample $(ETCDIR)/merger.conf; \
		echo "Installed sample configuration to $(ETCDIR)/merger.conf"; \
	else \
		echo "Configuration file already exists, skipping"; \
	fi

	# Set ownership
	$(CHOWN) -R $(INSTALL_USER):$(INSTALL_GROUP) $(VARDIR)
	$(CHOWN) -R $(INSTALL_USER):$(INSTALL_GROUP) $(LOGDIR)

	@echo "Installation complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Edit configuration: $(ETCDIR)/merger.conf"
	@echo "2. Test connection: asset-merger-engine validate"
	@echo "3. Run synchronization: asset-merger-engine sync"

# Uninstall the tool
.PHONY: uninstall
uninstall:
	@echo "Uninstalling asset-merger-engine..."

	# Remove binaries
	$(RM) $(BINDIR)/asset-merger-engine

	# Remove libraries
	$(RMDIR) $(LIBDIR)

	# Prompt before removing data
	@echo ""
	@echo "WARNING: Configuration and data directories will be preserved:"
	@echo "  - $(ETCDIR)"
	@echo "  - $(VARDIR)"
	@echo "  - $(LOGDIR)"
	@echo ""
	@echo "To completely remove, run:"
	@echo "  rm -rf $(ETCDIR) $(VARDIR) $(LOGDIR)"

	@echo "Uninstallation complete!"

# User installation (no root required)
.PHONY: user-install
user-install: check
	@echo "Installing asset-merger-engine for current user..."

	# Create user directories
	@mkdir -p $$HOME/.local/bin
	@mkdir -p $$HOME/.local/lib/asset-merger-engine
	@mkdir -p $$HOME/.config/asset-merger-engine
	@mkdir -p $$HOME/.local/share/asset-merger-engine/cache
	@mkdir -p $$HOME/.local/share/asset-merger-engine/output/processed
	@mkdir -p $$HOME/.local/share/asset-merger-engine/output/failed
	@mkdir -p $$HOME/.local/share/asset-merger-engine/output/reports
	@mkdir -p $$HOME/.local/share/asset-merger-engine/tmp
	@mkdir -p $$HOME/.local/share/asset-merger-engine/logs

	# Install scripts
	$(INSTALL) -m 755 bin/merger.sh $$HOME/.local/bin/asset-merger-engine

	# Install libraries
	$(INSTALL) -m 644 lib/common.sh $$HOME/.local/lib/asset-merger-engine/
	$(INSTALL) -m 644 lib/zabbix.sh $$HOME/.local/lib/asset-merger-engine/
	$(INSTALL) -m 644 lib/topdesk.sh $$HOME/.local/lib/asset-merger-engine/

	# Install configuration
	@if [ ! -f $$HOME/.config/asset-merger-engine/merger.conf ]; then \
		$(INSTALL) -m 640 etc/merger.conf.sample $$HOME/.config/asset-merger-engine/merger.conf; \
		echo "Installed sample configuration to $$HOME/.config/asset-merger-engine/merger.conf"; \
	else \
		echo "Configuration file already exists, skipping"; \
	fi

	@echo "User installation complete!"
	@echo ""
	@echo "Make sure $$HOME/.local/bin is in your PATH:"
	@echo '  export PATH="$$HOME/.local/bin:$$PATH"'
	@echo ""
	@echo "Next steps:"
	@echo "1. Edit configuration: $$HOME/.config/asset-merger-engine/merger.conf"
	@echo "2. Test connection: asset-merger-engine validate"
	@echo "3. Run synchronization: asset-merger-engine sync"

# User uninstall
.PHONY: user-uninstall
user-uninstall:
	@echo "Uninstalling asset-merger-engine for current user..."

	# Remove binaries
	@rm -f $$HOME/.local/bin/asset-merger-engine

	# Remove libraries
	@rm -rf $$HOME/.local/lib/asset-merger-engine

	@echo ""
	@echo "WARNING: Configuration and data directories will be preserved:"
	@echo "  - $$HOME/.config/asset-merger-engine"
	@echo "  - $$HOME/.local/share/asset-merger-engine"
	@echo ""
	@echo "To completely remove, run:"
	@echo "  rm -rf $$HOME/.config/asset-merger-engine $$HOME/.local/share/asset-merger-engine"

	@echo "User uninstallation complete!"

# Run tests
.PHONY: test
test:
	@echo "Running tests..."
	@./bin/merger.sh validate
	@echo "Tests complete!"

# Clean temporary files
.PHONY: clean
clean:
	@echo "Cleaning temporary files..."
	$(RM) tmp/*
	$(RM) var/run/*.lock
	$(RM) var/cache/*
	@echo "Cleanup complete!"

# Development targets
.PHONY: dev-install
dev-install:
	@echo "Setting up development environment..."
	@# Create user bin directory if it doesn't exist
	@mkdir -p $$HOME/.local/bin
	@# Create symlink in user's local bin
	@ln -sf $$(pwd)/bin/merger.sh $$HOME/.local/bin/asset-merger-engine-dev
	@echo "Development installation complete!"
	@echo ""
	@echo "Make sure $$HOME/.local/bin is in your PATH:"
	@echo '  export PATH="$$HOME/.local/bin:$$PATH"'
	@echo ""
	@echo "Run with: asset-merger-engine-dev"

.PHONY: dev-uninstall
dev-uninstall:
	@echo "Removing development environment..."
	@rm -f $$HOME/.local/bin/asset-merger-engine-dev
	@echo "Development uninstallation complete!"

.DEFAULT:
	@echo "Unknown target: $@"
	@echo "Run 'make help' for available targets"