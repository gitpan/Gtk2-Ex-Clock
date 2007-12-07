# Gtk2::Ex::Clock widget.

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

package Gtk2::Ex::Clock;

use strict;
use warnings;
use Gtk2;
use POSIX;
use Scalar::Util;
use Time::HiRes;

# Version 1 - the first version
# Version 2 - tweaks
#
our $VERSION = 2;


use constant {
  DEFAULT_FORMAT => '%H:%M',

  # not wrapped in Gtk2 version 1.161
  GDK_PRIORITY_REDRAW => (Glib::G_PRIORITY_HIGH_IDLE + 20),
};

# set this to 1 for some diagnostic prints
use constant DEBUG => 0;

use Glib::Object::Subclass
  Gtk2::Label::,
  properties => [Glib::ParamSpec->string
                 ('format',
                  'format',
                  'An strftime() format string to display the time.',
                  DEFAULT_FORMAT,
                  Glib::G_PARAM_READWRITE),

                 Glib::ParamSpec->scalar
                 ('timezone',
                  'timezone',
                  'The timezone to use in the display, either a string for the TZ environment variable, or a DateTime::TimeZone object.  An empty string or undef means the local timezone.',
                  Glib::G_PARAM_READWRITE),

                 Glib::ParamSpec->int
                 ('resolution',
                  'resolution',
                  'The resolution of the clock, in seconds, or 0 to decide this from the format string.',
                  0, 3600, 0,
                  Glib::G_PARAM_READWRITE)
                 ];

# $timer_margin is an extra period in milliseconds to add to the timer
# period requested.  It's designed to ensure we don't wake up before the
# target time boundary of 1 second or 1 minute if g_timeout_add ends up
# rounding to a clock tick boundary.
#
# In the unlikely event there's no sysconf value for CLK_TCK, assume the
# traditional 100 ticks/second, ie. a resolution of 10 milliseconds (giving
# a 20 ms margin).
#
my $timer_margin = sysconf(_SC_CLK_TCK);
if ($timer_margin == -1) { $timer_margin = 100; } # default assume 100 Hz
$timer_margin = 2 * 1000.0 / $timer_margin;
if (DEBUG) { print "timer margin $timer_margin milliseconds\n"; }

# $format is an strftime() format string.  Return true if it has 1 second
# resolution.
#
sub strftime_is_seconds {
  my ($format) = @_;
  # %c is ctime() style, includes seconds
  # %r is "%I:%M:%S %p"
  # %s is seconds since 1970 (a GNU extension)
  # %S is seconds 0 to 59
  # %T is "%H:%M:%S"
  # %X is locale preferred time, probably "%H:%M:%S"
  # modifiers standard E and O, plus GNU "-_0^"
  return ($format =~ /%[-_^0-9EO]*[crsSTX]/);
}

# $tz is a string setting for the TZ environment variable, or undef.
# $subr is a code reference.
# Call $subr with TZ set to $tz, or if $tz is the empty string or undef
# then just call $subr with no change to TZ.  There's no return value.
#
sub call_with_TZ {
  my ($tz, $subr) = @_;
  my $old_tz = $ENV{'TZ'};

  # if timezone undef or empty, or if it's the same as the current zone,
  # then avoid munging %ENV and the slowness of tzset()
  if (! defined $tz
      || $tz eq ''
      || (defined $old_tz && $tz eq $old_tz)) {
    &$subr();

  } else {
    $ENV{'TZ'} = $tz;
    POSIX::tzset();
    &$subr();
    if (defined $old_tz) {
      $ENV{'TZ'} = $old_tz;
    } else {
      delete $ENV{'TZ'};
    }
    POSIX::tzset();
  }
}

sub timer_callback {
  my ($weak_ref_self) = @_;
  my $self = $$weak_ref_self;
  if (! defined $self) {
    if (DEBUG) { print "Gtk2::Ex::Clock timer after destroyed, stopping\n"; }
    return 0; # stop timer
  }
  if (DEBUG) { print "$self run timer ", $self->{'timer_id'}||'undef', "\n"; }

  my $tod = Time::HiRes::gettimeofday();
  my $format   = $self->get('format');
  my $timezone = $self->get('timezone');
  my $str;

  if (ref($timezone) && $timezone->isa('DateTime::TimeZone')) {
    require DateTime;
    my $t = DateTime->now (time_zone => $timezone);
    $str = $t->strftime($format);

  } else {
    call_with_TZ ($timezone,
      sub { my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
              = localtime ($tod);
            $str = POSIX::strftime
              ($format,$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
          });
  }
  $self->set('label',$str);

  # Decide how long, in milliseconds, from $tod to the next multiple of
  # $self->{'decided_resolution'} seconds, ie. to either the next 1 second or
  # 1 minute boundary.  Plus the $timer_margin described above.
  #
  my $resolution = $self->{'decided_resolution'};
  my $milliseconds
    = POSIX::ceil ($timer_margin + 1000 * ($resolution
                                           - POSIX::fmod ($tod, $resolution)));
  my $weak_self = $self;
  Scalar::Util::weaken ($weak_self);
  $self->{'timer_id'} = Glib::Timeout->add
    ($milliseconds, \&timer_callback, \$weak_self, GDK_PRIORITY_REDRAW);

  if (DEBUG) {
    print "start timer ",$self->{'timer_id'},
      ", ${milliseconds}ms from $tod, to give ",
      $tod + $milliseconds / 1000.0,"\n";
  }
  return 0;  # remove previous timer
}

sub stop_timer {
  my ($self) = @_;
  if (defined ($self->{'timer_id'})) {
    if (DEBUG) { print "stop timer ",$self->{'timer_id'},"\n"; }
    Glib::Source->remove ($self->{'timer_id'});
    $self->{'timer_id'} = undef;
  }
}

sub decide_resolution_and_draw {
  my ($self) = @_;
  $self->{'decided_resolution'}
    = $self->get('resolution')
      || (strftime_is_seconds($self->get('format'))
          ? 1 : 60);
  if (DEBUG) {
    print "decided resolution ",$self->{'decided_resolution'},"\n";
  }
  stop_timer ($self);
  timer_callback (\$self);
}

sub SET_PROPERTY {
  my ($self, $pspec, $newval) = @_;
  $self->{$pspec->get_name} = $newval;  # per default GET_PROPERTY

  decide_resolution_and_draw ($self);
}

sub INIT_INSTANCE {
  my ($self) = @_;
  $self->set('use-markup', 1);
  decide_resolution_and_draw ($self);
}

sub FINALIZE_INSTANCE {
  my ($self) = @_;
  if (DEBUG) { print "$self destroy\n"; }
  stop_timer ($self);
}

1;
__END__

=head1 NAME

Gtk2::Ex::Clock -- simple digital clock widget

=head1 SYNOPSIS

 use Gtk2::Ex::Clock;

 my $clock = Gtk2::Ex::Clock->new ();

 # or a specified format, or a different timezone
 my $clock = Gtk2::Ex::Clock->new (format => '%I:%M<sup>%P</sup>',
                                   timezone => 'America/New_York');

 # or a DateTime::TimeZone object for the timezone
 use DateTime::TimeZone;
 my $timezone = DateTime::TimeZone->new (name => 'America/New_York');
 my $clock = Gtk2::Ex::Clock->new (timezone => $timezone);

=head1 WIDGET HIERARCHY

C<Gtk2::Ex::Clock> is a subclass of C<Gtk2::Label>.

    Gtk2::Widget
       Gtk2::Misc
          Gtk2::Label
             Gtk2::Ex::Clock

=head1 DESCRIPTION

C<Gtk2::Ex::Clock> displays a digital clock.  The default is 24-hour format
"%H:%M" local time, like "14:59".  The properties below allow other formats
and/or a specified timezone.  Pango markup like "<bold>" can be included for
font effects.

Gtk2::Ex::Clock is designed to be light weight and suitable for use
somewhere unobtrusive in a realtime or semi-realtime application.  The
right-hand end of a menubar is a good place for instance, depending on user
preferences.  In the default minutes display all it costs the program is a
timer waking to change a C<Gtk2::Label> once a minute.

=head1 FUNCTIONS

=over 4

=item C<Gtk2::Ex::Clock-E<gt>new (key=E<gt>value,...)>

Create and return a new clock widget.  Optional key/value pairs can set
initial properties, as per C<Glib::Object-E<gt>new>.  For example,

    my $clock = Gtk2::Ex::Clock->new (format => '%a %H:%M',
                                      timezone => 'Asia/Tokyo');

=back

=head1 PROPERTIES

=over 4

=item C<format> (string, default "%H:%M")

An C<strftime> format string for the date/time display.  See the C<strftime>
man page or the GNU C Library manual for possible C<%> conversions.

Date conversions can be included to show a day or date as well as the time.
This is good for a remote timezone where you might not be sure if it's today
or tomorrow there yet.

    my $clock = Gtk2::Ex::Clock->new (format => 'London %d%m %H:%M',
                                      timezone => 'Europe/London');

Pango markup can be used for bold, etc.  For example "am/pm" as superscript.

    my $clock = Gtk2::Ex::Clock->new(format=>'%I:%M<sup>%P</sup>');

Newlines can be included for multi-line display, for instance date on one
line and the time below it.  The various C<Gtk2::Label> and C<Gtk2::Misc>
properties can be used to control centring.  For example,

    my $clock = Gtk2::Ex::Clock->new (format  => "%d %b\n%H:%M",
                                      justify => 'center',
                                      xalign  => 0.5);

=item C<timezone> (string or C<DateTime::TimeZone>, default local time)

The timezone to use in the display.  An empty string or undef (undef is the
default) means local time.

For a string, the C<TZ> environment variable (C<$ENV{'TZ'}>) is set while
formatting the time (and restored so other parts of the program are not
affected).  See the C<tzset> man page or the GNU C Library manual under "TZ
Variable" for possible settings.

For a C<DateTime::TimeZone> object the time display calculations are done
using its information and a C<DateTime> object's C<strftime> method.  That
method may allow some extra conversions in the format string over what the C
library offers.

=item C<resolution> (integer, default from format)

The resolution, in seconds, of the clock.  The default 0 means look at the
format to decide whether seconds is needed or minutes is enough.  Formats
using %S and various other mostly-standard forms like %T and %X are
recognised as seconds, and anything else is minutes.  If that comes out
wrong you can force it by setting this property.

Incidentally, if you're only displaying hours then you probably don't want
hour resolution, since a system time change won't be recognised until the
requested resolution worth of real time has elapsed.

=back

The properties of C<Gtk2::Label> and C<Gtk2::Misc> can be used to variously
control padding, alignment, etc.

See the F<examples> directory in the sources for some complete programs
displaying clocks in various forms.

=head1 OTHER NOTES

The clock is implemented by updating a C<Gtk2::Label> under a timer.  This
is simple, and makes good use of the label widget's text drawing code, but
it does mean that with a variable width font the size of the widget can
change as the time changes.  For minutes display any resizes are hardly
noticable, but for seconds it may be best to use a fixed-width font, or to
C<set_size_request> for a fixed size (initial size plus a few pixels say),
or even try C<Gtk2::Ex::NoShrink>.

The way C<TZ> is temporarily changed to implement a non-local timezone could
be slightly on the slow side.  The GNU C Library (as of version 2.7) for
instance opens and re-reads a zoneinfo file on each change.  Doing that
(twice) each minute is fine, but for seconds you may prefer
C<DateTime::TimeZone>.  Changing C<TZ> probably isn't thread safe either,
though rumour has it you have to be very careful with threads and Gtk2-Perl
anyway, so you probably won't be using threads.  Again you can use a
C<DateTime::TimeZone> object if you're nervous.

=head1 HOME PAGE

L<http://www.geocities.com/user42_kevin/gtk2-ex-clock/index.html>

=head1 LICENSE

Gtk2::Ex::Clock is Copyright 2007 Kevin Ryde

Gtk2::Ex::Clock is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 3, or (at your option) any later
version.

Gtk2::Ex::Clock is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
Gtk2::Ex::Clock.  If not, see <http://www.gnu.org/licenses/>.

=head1 SEE ALSO

C<strftime(3)>, C<tzset(3)>, L<Gtk2>, L<Gtk2::Label>, L<Gtk2::Misc>,
L<DateTime::TimeZone>, L<DateTime>

=cut
