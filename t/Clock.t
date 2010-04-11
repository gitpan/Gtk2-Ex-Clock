#!/usr/bin/perl

# Copyright 2007, 2008, 2009, 2010 Kevin Ryde

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

use 5.008;
use strict;
use warnings;
use Test::More tests => 30;

BEGIN { SKIP: { eval 'use Test::NoWarnings; 1'
                  or skip 'Test::NoWarnings not available', 1; } }

use lib 't';
use MyTestHelpers;

require Gtk2::Ex::Clock;

{
  my $want_version = 11;
  is ($Gtk2::Ex::Clock::VERSION, $want_version, 'VERSION variable');
  is (Gtk2::Ex::Clock->VERSION,  $want_version, 'VERSION class method');

  ok (eval { Gtk2::Ex::Clock->VERSION($want_version); 1 },
      "VERSION class check $want_version");
  my $check_version = $want_version + 1000;
  ok (! eval { Gtk2::Ex::Clock->VERSION($check_version); 1 },
      "VERSION class check $check_version");

  my $clock = Gtk2::Ex::Clock->new;
  is ($clock->VERSION, $want_version, 'VERSION object method');
  ok (eval { $clock->VERSION($want_version); 1 },
      "VERSION object check $want_version");
  ok (! eval { $clock->VERSION($check_version); 1 },
      "VERSION object check $check_version");
}

require Gtk2;
MyTestHelpers::glib_gtk_versions();

require POSIX;
diag ("POSIX::_SC_CLK_TCK() constant ",(POSIX->can('_SC_CLK_TCK')
                                        ? "exists" : "doesn't exist"));
if (POSIX->can('_SC_CLK_TCK')) {
  my $clk_tck;
  my $ok = eval { $clk_tck = POSIX::sysconf (POSIX::_SC_CLK_TCK()); 1 };
  diag "POSIX::sysconf(_SC_CLK_TCK) is ",
    (! $ok ? "error $@" : (defined $clk_tck ? $clk_tck : '[undef]'));
}


#-----------------------------------------------------------------------------
# strftime_is_seconds()

ok (  Gtk2::Ex::Clock::strftime_is_seconds("%c"),    "%c");
ok (  Gtk2::Ex::Clock::strftime_is_seconds("x %r y"),"x %r y");
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%s"),    "%s");
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%X"),    "%X");
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%6s"),   "%6s");
ok (! Gtk2::Ex::Clock::strftime_is_seconds("%6dS"),  "%6dS");
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%S"),    "%S");
ok (! Gtk2::Ex::Clock::strftime_is_seconds("%H:%M"), "%H:%M");
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%ES"),   "%ES");
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%OS"),   "%OS");
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%0S"),   "%0S");
ok (! Gtk2::Ex::Clock::strftime_is_seconds("%MS"),   "%MS");
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%-12S"), "%-12S");
ok (! Gtk2::Ex::Clock::strftime_is_seconds("%%Something %H:%M"),
    "%%Something %H:%M");

# DateTime method forms
foreach my $method ('second', 'sec', 'hms', 'time', 'datetime', 'iso8601',
                    'epoch') {
  my $format = "blah %{$method} blah";
  ok (Gtk2::Ex::Clock::strftime_is_seconds($format), $format);
}

#-----------------------------------------------------------------------------
# weakening

# no circular reference between the clock and the timer callback it
# installs
{
  my $clock = Gtk2::Ex::Clock->new;
  require Scalar::Util;
  Scalar::Util::weaken ($clock);
  is ($clock, undef, 'should be garbage collected when weakened');
}

exit 0;
