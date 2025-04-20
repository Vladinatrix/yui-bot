# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
# Process this file with automake to produce Makefile.in

ACLOCAL_AMFLAGS = -I m4

# --- Files to be installed ---
pkgdatadir = $(datarootdir)/$(PACKAGE_NAME)
dist_pkgdata_SCRIPTS = yui_bot.py
dist_pkgdata_DATA = requirements.txt yui-bot.env.example LICENSE README.md

# Install systemd service file if systemd support was detected by configure
if HAVE_SYSTEMD
systemdsystemunit_DATA = service/yui-bot.service
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
    test-project.sh  # << ADDED test script to distribution

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
# Variables (allow override from environment)
RPM_BUILD_DIR ?= $(HOME)/rpmbuild
RPMBUILD ?= rpmbuild
# Calculated paths
RPM_SOURCES_DIR = $(RPM_BUILD_DIR)/SOURCES
RPM_SPECS_DIR = $(RPM_BUILD_DIR)/SPECS
RPM_SPEC_FILE = $(top_srcdir)/rpm/@PACKAGE_NAME@.spec
RPM_SPEC_BASENAME = $(notdir $(RPM_SPEC_FILE))
DIST_TARBALL = $(PACKAGE_TARNAME)-$(PACKAGE_VERSION).tar.gz

# Target to build SRPM
srpm: dist
	@echo "--- Building SRPM ---"
	$(MKDIR_P) "$(RPM_SOURCES_DIR)" "$(RPM_SPECS_DIR)"
	@echo "Copying Source Tarball '$(top_builddir)/$(DIST_TARBALL)' to $(RPM_SOURCES_DIR)/"
	cp -f "$(top_builddir)/$(DIST_TARBALL)" "$(RPM_SOURCES_DIR)/"
	@echo "Copying Spec File '$(RPM_SPEC_FILE)' to $(RPM_SPECS_DIR)/"
	cp -f "$(RPM_SPEC_FILE)" "$(RPM_SPECS_DIR)/"
	@echo "Running $(RPMBUILD) -bs..."
	$(RPMBUILD) -bs "$(RPM_SPECS_DIR)/$(RPM_SPEC_BASENAME)"
	@echo "---------------------"; @echo "SRPM should be in $(RPM_BUILD_DIR)/SRPMS/"; @echo "---------------------"

# Target to build Binary and Source RPMs
rpm: dist
	@echo "--- Building RPMs (Binary & Source) ---"
	$(MKDIR_P) "$(RPM_SOURCES_DIR)" "$(RPM_SPECS_DIR)"
	@echo "Copying Source Tarball '$(top_builddir)/$(DIST_TARBALL)' to $(RPM_SOURCES_DIR)/"
	cp -f "$(top_builddir)/$(DIST_TARBALL)" "$(RPM_SOURCES_DIR)/"
	@echo "Copying Spec File '$(RPM_SPEC_FILE)' to $(RPM_SPECS_DIR)/"
	cp -f "$(RPM_SPEC_FILE)" "$(RPM_SPECS_DIR)/"
	@echo "Running $(RPMBUILD) -ba..."
	$(RPMBUILD) -ba "$(RPM_SPECS_DIR)/$(RPM_SPEC_BASENAME)"
	@echo "---------------------"; @echo "RPMs should be in $(RPM_BUILD_DIR)/RPMS/"; @echo "SRPM should be in $(RPM_BUILD_DIR)/SRPMS/"; @echo "---------------------"

# Declare phony targets
.PHONY: check-deps rpm srpm smokecheck # << ADDED smokecheck
