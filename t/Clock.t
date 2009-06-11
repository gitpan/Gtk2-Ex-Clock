#!/usr/bin/perl

# Copyright 2007, 2008, 2009 Kevin Ryde

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
use Gtk2::Ex::Clock;
use Test::More tests => 25;


my $want_version = 8;
ok ($Gtk2::Ex::Clock::VERSION >= $want_version, 'VERSION variable');
ok (Gtk2::Ex::Clock->VERSION  >= $want_version, 'VERSION class method');
Gtk2::Ex::Clock->VERSION ($want_version);
{
  my $clock = Gtk2::Ex::Clock->new;
  ok ($clock->VERSION  >= $want_version, 'VERSION object method');
  $clock->VERSION ($want_version);
}

require Gtk2;
diag ("Perl-Gtk2 version ",Gtk2->VERSION);
diag ("Perl-Glib version ",Glib->VERSION);
diag ("Compiled against Glib version ",
      Glib::MAJOR_VERSION(), ".",
      Glib::MINOR_VERSION(), ".",
      Glib::MICRO_VERSION(), ".");
diag ("Running on       Glib version ",
      Glib::major_version(), ".",
      Glib::minor_version(), ".",
      Glib::micro_version(), ".");
diag ("Compiled against Gtk version ",
      Gtk2::MAJOR_VERSION(), ".",
      Gtk2::MINOR_VERSION(), ".",
      Gtk2::MICRO_VERSION(), ".");
diag ("Running on       Gtk version ",
      Gtk2::major_version(), ".",
      Gtk2::minor_version(), ".",
      Gtk2::micro_version(), ".");

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
