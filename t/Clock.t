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


use Test::More tests => 22;
use Gtk2;
use Gtk2::Ex::Clock;
use Scalar::Util;


ok ($Gtk2::Ex::Clock::VERSION >= 3);
ok (Gtk2::Ex::Clock->VERSION >= 3);

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


{ # undef for no change
  $ENV{'TZ'} = 'GMT';
  Gtk2::Ex::Clock::call_with_TZ (undef, sub {
                                   is ($ENV{'TZ'}, 'GMT');
                                 });
  is ($ENV{'TZ'}, 'GMT');
}
{ # empty for no change
  $ENV{'TZ'} = 'GMT';
  Gtk2::Ex::Clock::call_with_TZ ('', sub {
                                   is ($ENV{'TZ'}, 'GMT');
                                 });
  is ($ENV{'TZ'}, 'GMT');
}
{ # something the same
  $ENV{'TZ'} = 'GMT';
  Gtk2::Ex::Clock::call_with_TZ ('GMT', sub {
                                   is ($ENV{'TZ'}, 'GMT');
                                 });
  is ($ENV{'TZ'}, 'GMT');
}


SKIP: {
  if (! Gtk2->init_check) { skip 'due to no DISPLAY available', 1; }

  # no circular reference between the clock and the timer callback it installs
  {
    my $clock = Gtk2::Ex::Clock->new;
    Scalar::Util::weaken ($clock);
    is (defined $clock ? 'defined' : 'not defined',
        'not defined',
        'should be garbage collected when weakened');
  }
}

exit 0;
