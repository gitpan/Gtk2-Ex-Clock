# Gtk2::Ex::Clock widget tests.

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


use Test;
BEGIN {
  plan (tests => 15);
}
use Gtk2;
use Gtk2::Ex::Clock;
use Scalar::Util;


ok ($Gtk2::Ex::Clock::VERSION >= 0);

ok (  Gtk2::Ex::Clock::strftime_is_seconds("%c"));
ok (  Gtk2::Ex::Clock::strftime_is_seconds("x %r y"));
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%s"));
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%X"));
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%6s"));
ok (! Gtk2::Ex::Clock::strftime_is_seconds("%6dS"));
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%S"));
ok (! Gtk2::Ex::Clock::strftime_is_seconds("%H:%M"));
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%ES"));
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%OS"));
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%0S"));
ok (! Gtk2::Ex::Clock::strftime_is_seconds("%MS"));
ok (  Gtk2::Ex::Clock::strftime_is_seconds("%-12S"));

my $if_no_display = Gtk2->init_check ? 0 : 'Skip due to no DISPLAY available';

# this test is designed to ensure there's no circular reference between the
# clock and the timer callback it installs
skip ($if_no_display, sub {
        my $clock = Gtk2::Ex::Clock->new;
        Scalar::Util::weaken ($clock);
        return ! defined $clock;
      }, 1, 'should be garbage collected when no longer referenced');

exit 0;
