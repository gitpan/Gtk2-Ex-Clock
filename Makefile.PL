#!/usr/bin/perl

# Copyright 2007, 2008 Kevin Ryde

# This file is part of Gtk2-Ex-Clock.
#
# Gtk2-Ex-Clock is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3, or (at your option) any later
# version.
#
# Gtk2-Ex-Clock is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with Gtk2-Ex-Clock.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile
  (NAME         => 'Gtk2::Ex::Clock',
   ABSTRACT     => 'Simple digital clock widget.',
   VERSION_FROM => 'lib/Gtk2/Ex/Clock.pm',
   AUTHOR       => 'Kevin Ryde <user42@zip.com.au>',
   LICENSE      => 'gpl',
   SIGN         => 1,

   PREREQ_PM    => {
                    # Gtk2 version 1.200 for GDK_PRIORITY_REDRAW
                    # (demanding the newest for just one constant is pretty
                    # gratuitous, but you'll almost certainly want 1.200 for
                    # various bug fixes too)
                    'Gtk2' => '1.200',

                    # actually this is only for the string timezone case,
                    # but it's small enough to grab always
                    'Tie::TZ' => 0,

                    # builtin in recent perl anyway
                    'Time::HiRes' => 0,

                    # actually Gtk2-Perl requires perl 5.8, which has
                    # Scalar::Util builtin already
                    'Scalar::Util' => 0,
                   },
   clean        => { FILES => "Clock.html" },

   EXTRA_META => <<'HERE',
no_index:
    directory:
        - devel
resources:
    homepage: http://www.geocities.com/user42_kevin/gtk2-ex-clock/index.html
HERE
  );




sub MY::postamble {
  return <<'MAKE_FRAG';

Clock.html: lib/Gtk2/Ex/Clock.pm Makefile
	-perl -MPod::Simple::HTML -e Pod::Simple::HTML::go \
	  lib/Gtk2/Ex/Clock.pm \
	| sed 's!http://search.cpan.org/perldoc?Gtk2%3A%3A\([^"%]*\)"!http://gtk2-perl.sourceforge.net/doc/pod/Gtk2/\1.html"!' \
	  >Clock.html

myman:
	mv MANIFEST MANIFEST.old
	touch SIGNATURE
	(make manifest 2>&1; diff -u MANIFEST.old MANIFEST) |less

CHECKFILES = $(TO_INST_PM) t/*.t examples/*.pl devel/*.pl
lint:
	for i in $(CHECKFILES); do perl -MO=Lint $$i; done
	podchecker    $(CHECKFILES)
pc:
	perlcritic $(CHECKFILES)

# find files in the dist with mod times this year, but without this year in
# the copyright line
copyright-years-check:
	year=`date +%Y`; \
	tar tvfz $(DISTVNAME).tar.gz \
	| grep $$year- \
	| sed 's:^.*$(DISTVNAME)/::' \
	| (result=0; \
	  while read i; do \
	    case $$i in \
	      '' | */ \
	      | debian/changelog | debian/compat | debian/control \
	      | t/pod.t \
	      | COPYING | MANIFEST* | SIGNATURE | META.yml) \
	      continue ;; \
	    esac; \
	    if test -e "$(srcdir)/$$i"; then f="$(srcdir)/$$i"; \
	    else f="$$i"; fi; \
	    if ! grep -q "Copyright.*$$year" $$f; then \
	      echo "$$i":"1: this file"; \
	      grep Copyright $$f; \
	      result=1; \
	    fi; \
	  done; \
	  exit $$result)

debug-constants-check:
	if egrep -n 'DEBUG => [^0]' $(TO_INST_PM); then exit 1; else exit 0; fi

diff-prev:
	rm -rf diff.tmp
	mkdir diff.tmp
	cd diff.tmp \
	&& tar xfz ../$(NAME)-`expr $(VERSION) - 1`.tar.gz \
	&& tar xfz ../$(NAME)-$(VERSION).tar.gz
	-cd diff.tmp; diff -ur $(NAME)-`expr $(VERSION) - 1` \
	                       $(NAME)-$(VERSION) >tree.diff
	-less diff.tmp/tree.diff
	rm -rf diff.tmp

MAKE_FRAG
}
