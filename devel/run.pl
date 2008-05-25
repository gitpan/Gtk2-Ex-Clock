#!/usr/bin/perl

# Copyright 2008 Kevin Ryde

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
use Gtk2 '-init';
use Gtk2::Ex::Clock;
use POSIX qw(setlocale LC_ALL LC_TIME);
use DateTime;
use DateTime::TimeZone;

{
  $ENV{'LANG'} = 'ja_JP';
  setlocale(LC_ALL, '') or die;
}

{
  my $locale = setlocale (LC_TIME);
  DateTime->DefaultLocale ($locale);
  print "DateTime::DefaultLocale is ", DateTime->DefaultLocale, "\n";
}

my $toplevel = Gtk2::Window->new('toplevel');
$toplevel->signal_connect (destroy => sub { Gtk2->main_quit; });

my $vbox = Gtk2::VBox->new;
$toplevel->add ($vbox);

{
  my $clock = Gtk2::Ex::Clock->new (format => "\x{263A} %a %I:%M%P",
                                    timezone => 'GMT');
  $vbox->pack_start ($clock, 1,1,0);
}
{
  my $tz = DateTime::TimeZone->new (name => 'GMT');
  my $clock = Gtk2::Ex::Clock->new (format => "\x{263A} %a %I:%M%P",
                                    timezone => $tz);
  $vbox->pack_start ($clock, 1,1,0);
}

$toplevel->show_all;
Gtk2->main;
exit 0;
