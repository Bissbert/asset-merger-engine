# Makefile for topdesk-zbx-merger
# POSIX-compliant Makefile for installation and management

# Variables
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib/topdesk-zbx-merger
ETCDIR = /etc/topdesk-zbx-merger
VARDIR = /var/lib/topdesk-zbx-merger
LOGDIR = /var/log/topdesk-zbx-merger

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
	@echo "Topdesk-Zabbix Merger Installation"
	@echo "=================================="
	@echo ""
	@echo "Targets:"
	@echo "  install       Install the merger tool"
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
	@echo "  make install"
	@echo "  make install PREFIX=/opt/merger"
	@echo "  make check"

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
	@echo "Installing topdesk-zbx-merger..."

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
	$(INSTALL) -m 755 bin/merger.sh $(BINDIR)/topdesk-zbx-merger

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
	@echo "2. Test connection: topdesk-zbx-merger validate"
	@echo "3. Run synchronization: topdesk-zbx-merger sync"

# Uninstall the tool
.PHONY: uninstall
uninstall:
	@echo "Uninstalling topdesk-zbx-merger..."

	# Remove binaries
	$(RM) $(BINDIR)/topdesk-zbx-merger

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
	@ln -sf $$(pwd)/bin/merger.sh /usr/local/bin/topdesk-zbx-merger-dev
	@echo "Development installation complete!"

.PHONY: dev-uninstall
dev-uninstall:
	@echo "Removing development environment..."
	@rm -f /usr/local/bin/topdesk-zbx-merger-dev
	@echo "Development uninstallation complete!"

.DEFAULT:
	@echo "Unknown target: $@"
	@echo "Run 'make help' for available targets"