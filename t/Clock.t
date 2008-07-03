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
use Test::More tests => 24;
use Gtk2;
use Gtk2::Ex::Clock;


ok ($Gtk2::Ex::Clock::VERSION >= 5);
ok (Gtk2::Ex::Clock->VERSION >= 5);

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

# DateTime method forms
foreach my $method ('second', 'sec', 'hms', 'time', 'datetime', 'iso8601',
                    'epoch') {
  my $format = "blah %{$method} blah";
  ok (  Gtk2::Ex::Clock::strftime_is_seconds($format), $format);
}

{
 SKIP: {
    if (! Gtk2->init_check) { skip 'due to no DISPLAY available', 1; }

    # no circular reference between the clock and the timer callback it
    # installs
    {
      my $clock = Gtk2::Ex::Clock->new;
      require Scalar::Util;
      Scalar::Util::weaken ($clock);
      is (defined $clock ? 'defined' : 'not defined',
          'not defined',
          'should be garbage collected when weakened');
    }
  }
}

# check that a mere "local $ENV{TZ}" affects localtime, since that's all we
# do in the code; though as noted in the "perlport" pod on some systems it
# might have no effect at all
{
 SKIP: {
    require POSIX;
    $ENV{'TZ'} = 'GMT';
    POSIX::tzset();
    my (undef, undef, $gmt_hour) = localtime (0);

    $ENV{'TZ'} = 'BST+1';
    POSIX::tzset();
    my (undef, undef, $bst_hour) = localtime (0);

    if ($gmt_hour == $bst_hour) {
      skip 'due to TZ variable having no effect', 1;
    }

    $ENV{'TZ'} = 'GMT';
    POSIX::tzset();

    my $est_hour;
    { local $ENV{'TZ'} = 'EST+10';
      (undef, undef, $est_hour) = localtime (0);
    }
    isnt ($gmt_hour, $est_hour);
  }
  POSIX::tzset();
}

exit 0;
