# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
# Process this file with automake to produce Makefile.in

ACLOCAL_AMFLAGS = -I m4

# --- Explicit Default Target ---
all:

# --- Files to be installed ---
pkgdatadir = $(datarootdir)/$(PACKAGE_NAME)
dist_pkgdata_SCRIPTS = yui_bot.py
# Add the *generated* service file to pkgdata if systemd is enabled
if HAVE_SYSTEMD
dist_pkgdata_DATA = requirements.txt yui-bot.env.example service/yui-bot.service
else
dist_pkgdata_DATA = requirements.txt yui-bot.env.example
endif

# Install the Python configuration helper script to sbin
sbin_SCRIPTS = configure-yui-bot.py

# --- Files included in dist tarball ---
EXTRA_DIST = \
    configure.ac \
    Makefile.am \
    service/yui-bot.service.in \
    service/yui-bot.initd.in \
    rpm/yui-bot.spec \
    LICENSE \
    README.md \
    configure-yui-bot.py \
    test-project.sh

# --- Cleanup ---
CLEANFILES = service/yui-bot.service \
             service/yui-bot.initd

# --- Custom Check Target ---
check-deps:
	@echo "Checking Python dependencies from requirements.txt..."
	@$(PIP3) install --dry-run -r $(srcdir)/requirements.txt

# --- Custom Smoke Check Target ---
smokecheck:
	@echo "--- Running Project Smoke Checks (Syntax, Build, Lint) ---"
	$(SHELL) $(top_srcdir)/test-project.sh
	@echo "--- Smoke Checks Complete ---"

# --- RPM Building Targets ---
RPM_BUILD_DIR ?= $(HOME)/rpmbuild
RPMBUILD ?= rpmbuild
RPM_SOURCES_DIR = $(RPM_BUILD_DIR)/SOURCES
RPM_SPECS_DIR = $(RPM_BUILD_DIR)/SPECS
RPM_SPEC_FILE = $(top_srcdir)/rpm/@PACKAGE_NAME@.spec
DIST_TARBALL = $(PACKAGE_TARNAME)-$(PACKAGE_VERSION).tar.gz

srpm: dist
	@echo "--- Building SRPM ---"
	$(MKDIR_P) "$(RPM_SOURCES_DIR)" "$(RPM_SPECS_DIR)"
	@echo "Copying Source Tarball '$(top_builddir)/$(DIST_TARBALL)' to $(RPM_SOURCES_DIR)/"
	cp -f "$(top_builddir)/$(DIST_TARBALL)" "$(RPM_SOURCES_DIR)/"
	@echo "Copying Spec File '$(RPM_SPEC_FILE)' to $(RPM_SPECS_DIR)/"
	cp -f "$(RPM_SPEC_FILE)" "$(RPM_SPECS_DIR)/"
	@echo "Running $(RPMBUILD) -bs..."
	spec_basename=$$(basename "$(RPM_SPEC_FILE)"); \
	$(RPMBUILD) -bs "$(RPM_SPECS_DIR)/$$spec_basename"
	@echo "---------------------"
	@echo "SRPM should be in $(RPM_BUILD_DIR)/SRPMS/"
	@echo "---------------------"

rpm: dist
	@echo "--- Building RPMs (Binary & Source) ---"
	$(MKDIR_P) "$(RPM_SOURCES_DIR)" "$(RPM_SPECS_DIR)"
	@echo "Copying Source Tarball '$(top_builddir)/$(DIST_TARBALL)' to $(RPM_SOURCES_DIR)/"
	cp -f "$(top_builddir)/$(DIST_TARBALL)" "$(RPM_SOURCES_DIR)/"
	@echo "Copying Spec File '$(RPM_SPEC_FILE)' to $(RPM_SPECS_DIR)/"
	cp -f "$(RPM_SPEC_FILE)" "$(RPM_SPECS_DIR)/"
	@echo "Running $(RPMBUILD) -ba..."
	spec_basename=$$(basename "$(RPM_SPEC_FILE)"); \
	$(RPMBUILD) -ba "$(RPM_SPECS_DIR)/$$spec_basename"
	@echo "---------------------"
	@echo "Binary RPM(s) should be in $(RPM_BUILD_DIR)/RPMS/"
	@echo "SRPM should be in $(RPM_BUILD_DIR)/SRPMS/"
	@echo "---------------------"

# Declare phony targets
.PHONY: check-deps rpm srpm smokecheck all
