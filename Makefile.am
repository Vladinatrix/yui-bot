# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
#
# Process this file with automake to produce Makefile.in

ACLOCAL_AMFLAGS = -I m4

# --- Files to be installed ---
pkgdatadir = $(datarootdir)/$(PACKAGE_NAME)
dist_pkgdata_SCRIPTS = yui_bot.py # << Script name matches
dist_pkgdata_DATA = requirements.txt yui-bot.env.example LICENSE README.md # << Example file name matches

# Install systemd service file if systemd support was detected by configure
if HAVE_SYSTEMD
systemdsystemunit_DATA = service/yui-bot.service # << Service file name matches
endif

# --- Files included in dist tarball ---
EXTRA_DIST = \
    configure.ac \
    Makefile.am \
    service/yui-bot.service.in \
    service/yui-bot.initd.in \
    rpm/yui-bot.spec \
    LICENSE \
    README.md

# --- Cleanup ---
CLEANFILES = service/yui-bot.service \
             service/yui-bot.initd

# Optional: Add a target for checking dependencies without installing
check-deps:
	@echo "Checking Python dependencies from requirements.txt..."
	@$(PIP3) install --dry-run -r $(srcdir)/requirements.txt

.PHONY: check-deps
