#!/usr/bin/perl

# Copyright 2007 Kevin Ryde

# This file is part of Gtk2::Ex::Clock.
#
# Gtk2::Ex::Clock is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3, or (at your option) any later
# version.
#
# Gtk2::Ex::Clock is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with Gtk2::Ex::Clock.  If not, see <http://www.gnu.org/licenses/>.

use ExtUtils::MakeMaker;

WriteMakefile
    (NAME         => 'Gtk2::Ex::Clock',
     ABSTRACT     => 'Simple digital clock widget.',
     VERSION_FROM => 'lib/Gtk2/Ex/Clock.pm',
     AUTHOR       => 'Kevin Ryde <user42@zip.com.au>',
     LICENSE      => 'gpl',
     SIGN         => 1,
     
     PREREQ_PM    => { Gtk2 => 0,         # any version should be ok
                       Time::HiRes => 0,  # builtin in recent perl
                       Scalar::Util => 0, # builtin in recent perl
                     },
     clean        => { FILES => "Clock.html" },
    );

sub MY::postamble {
    return <<'MAKE_FRAG';

lint:
	perl -MO=Lint lib/Gtk2/Ex/Clock.pm
	podchecker lib/Gtk2/Ex/Clock.pm

myman:
	rm -f MANIFEST
	touch SIGNATURE
	make manifest

Clock.html: lib/Gtk2/Ex/Clock.pm Makefile
	-perl -MPod::Simple::HTML -e Pod::Simple::HTML::go \
	  lib/Gtk2/Ex/Clock.pm >Clock.html

MAKE_FRAG
}
