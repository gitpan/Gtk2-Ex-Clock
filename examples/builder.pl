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


# This is an example of making a clock in a GUI with Gtk2::Builder.  The
# class name is "Gtk2__Ex__Clock", as usual for Gtk2-Perl package name to
# Gtk type name conversion.

use strict;
use warnings;
use Gtk2 '-init';
use Gtk2::Ex::Clock;

my $builder = Gtk2::Builder->new;
$builder->add_from_string ('
<interface>
  <object class="GtkWindow" id="toplevel">
    <property name="type">toplevel</property>
    <signal name="destroy" handler="do_quit"/>
    <child>
      <object class="GtkHBox" id="hbox">
        <child>
          <object class="Gtk2__Ex__Clock" id="clock">
            <property name="xpad">10</property>  <!-- per GtkMisc -->
          </object>
        </child>
        <child>
          <object class="GtkButton" id="quit_button">
            <property name="label">gtk-quit</property>
            <property name="use-stock">TRUE</property>
            <signal name="clicked" handler="do_quit"/>
          </object>
        </child>
      </object>
    </child>
  </object>
</interface>
');

sub do_quit { Gtk2->main_quit; }
$builder->connect_signals;

$builder->get_object('toplevel')->show_all;
Gtk2->main;
exit 0;
