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

package Gtk2::Ex::Clock;
use strict;
use warnings;
use Gtk2 1.200; # version 1.200 for GDK_PRIORITY_REDRAW
use POSIX ();
use Scalar::Util;
use Time::HiRes;

our $VERSION = 8;

use constant DEFAULT_FORMAT => '%H:%M';

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
# period requested.  It's designed to ensure the timer doesn't fire before
# the target time boundary of 1 second or 1 minute if g_timeout_add() (or
# the select() within it) ends up rounding to a clock tick boundary.
#
# In the unlikely event there's no sysconf value for CLK_TCK, or no sysconf
# func at all, assume the traditional 100 ticks/second, ie. a resolution of
# 10 milliseconds (giving a 20 ms margin).
#
my $timer_margin = -1;  # default -1 like the error return from sysconf()
eval { $timer_margin = POSIX::sysconf (POSIX::_SC_CLK_TCK()); };
if ($timer_margin == -1) { $timer_margin = 100; } # default assume 100 Hz
$timer_margin = 2 * 1000.0 / $timer_margin;
if (DEBUG) { print "timer margin $timer_margin milliseconds\n"; }


sub INIT_INSTANCE {
  my ($self) = @_;
  $self->{'format'} = DEFAULT_FORMAT;
  $self->set_use_markup (1);
  _decide_resolution_and_update ($self);
}

sub FINALIZE_INSTANCE {
  my ($self) = @_;
  if (DEBUG) { print "$self destroy\n"; }
  _stop_timer ($self);
}

sub SET_PROPERTY {
  my ($self, $pspec, $newval) = @_;
  $self->{$pspec->get_name} = $newval;  # per default GET_PROPERTY

  _decide_resolution_and_update ($self);
}

sub _decide_resolution_and_update {
  my ($self) = @_;
  $self->{'decided_resolution'}
    = $self->get('resolution')
      || (strftime_is_seconds($self->{'format'}) ? 1 : 60);
  if (DEBUG) {
    print "decided resolution ",$self->{'decided_resolution'},"\n";
  }
  _stop_timer ($self);
  _timer_callback (\$self);
}

sub _stop_timer {
  my ($self) = @_;
  if (my $id = delete $self->{'timer_id'}) {
    if (DEBUG) { print "stop timer $id\n"; }
    Glib::Source->remove ($id);
  }
}

sub _timer_callback {
  my ($ref_weak_self) = @_;
  # probably FINALIZE_INSTANCE should run before zapped by weakening, but in
  # any case if called after weakened then stop the timer
  my $self = $$ref_weak_self || return 0; # Glib::SOURCE_REMOVE
  if (DEBUG) { print "$self run timer ", $self->{'timer_id'}||'undef', "\n"; }

  my $tod = Time::HiRes::gettimeofday();
  my $format   = $self->{'format'};
  my $timezone = $self->{'timezone'};
  my $str;

  if (Scalar::Util::blessed($timezone)
      && $timezone->isa('DateTime::TimeZone')) {
    require DateTime;
    my $t = DateTime->from_epoch (epoch => $tod, time_zone => $timezone);
    $str = $t->strftime ($format);

  } elsif (defined $timezone && $timezone ne '') {
    # in the given TZ timezone string
    require Tie::TZ;
    local $Tie::TZ::TZ = $timezone;
    $str = strftime_wide ($format, localtime ($tod));

  } else {
    # in the current timezone
    $str = strftime_wide ($format, localtime ($tod));
  }
  $self->set_label ($str);

  # Decide how long, in milliseconds, from $tod to the next multiple of
  # $self->{'decided_resolution'} seconds, either the next 1 second or
  # 1 minute boundary.  Plus the $timer_margin described above.
  #
  my $resolution = $self->{'decided_resolution'};
  my $milliseconds
    = POSIX::ceil ($timer_margin
                   + 1000 * ($resolution - POSIX::fmod ($tod, $resolution)));
  my $weak_self = $self;
  Scalar::Util::weaken ($weak_self);
  $self->{'timer_id'} = Glib::Timeout->add
    ($milliseconds, \&_timer_callback, \$weak_self, Gtk2::GDK_PRIORITY_REDRAW);

  if (DEBUG) {
    print "start timer ",$self->{'timer_id'},
      ", ${milliseconds}ms from $tod, to give ",
        $tod + $milliseconds / 1000.0,"\n";
  }
  return 0; # Glib::SOURCE_REMOVE # the previous timer
}

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
  #
  # DateTime extras:
  # %N is nanoseconds, which really can't work, so ignore
  #
  $format =~ s/%%//g; # literal "%"s, so eg. "%%Something" is not "%S"
  return ($format =~ /%[-_^0-9EO]*
                       ([crsSTX]
                       |\{(sec(ond)?|hms|(date)?time|iso8601|epoch)})/x);
}

# strftime_wide() $format and the return are wide char strings, whereas
# plain POSIX::strftime() takes and returns locale bytes.
#
# As noted in the pod below this is imperfect in that the encode/decode will
# lose chars not representable in the locale charset.  g_date_strftime() is
# unicode and could suit, but it's just dates, not times, so no good.  Does
# someone have a wstrftime() kicking around?
#
sub strftime_wide {
  my ($format, @args) = @_;
  require I18N::Langinfo;
  my $charset = I18N::Langinfo::langinfo (I18N::Langinfo::CODESET());
  require Encode;
  $format = Encode::encode ($charset, $format);
  my $str = POSIX::strftime ($format, @args);
  return Encode::decode ($charset, $str);
}

1;
__END__

=head1 NAME

Gtk2::Ex::Clock -- simple digital clock widget

=head1 SYNOPSIS

 use Gtk2::Ex::Clock;
 my $clock = Gtk2::Ex::Clock->new;  # local time

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

C<Gtk2::Ex::Clock> is designed to be light weight and suitable for use
somewhere unobtrusive in a realtime or semi-realtime application.  The
right-hand end of a menubar is a good place for instance, depending on user
preferences.  In the default minutes display all it costs the program is a
timer waking once a minute to change a C<Gtk2::Label>.

=head1 FUNCTIONS

=over 4

=item C<< $clock = Gtk2::Ex::Clock->new (key=>value,...) >>

Create and return a new clock widget.  Optional key/value pairs set initial
properties as per C<< Glib::Object->new >>.  For example,

    my $clock = Gtk2::Ex::Clock->new (format => '%a %H:%M',
                                      timezone => 'Asia/Tokyo');

=back

=head1 PROPERTIES

=over 4

=item C<format> (string, default C<"%H:%M">)

An C<strftime> format string for the date/time display.  See the C<strftime>
man page or the GNU C Library manual for possible C<%> conversions.

Date conversions can be included to show a day or date as well as the time.
This is good for a remote timezone where you might not be sure if it's today
or tomorrow yet.

    my $clock = Gtk2::Ex::Clock->new (format => 'London %d%m %H:%M',
                                      timezone => 'Europe/London');

Pango markup can be used for bold, etc.  For example "am/pm" as superscript.

    my $clock = Gtk2::Ex::Clock->new(format=>'%I:%M<sup>%P</sup>');

Newlines can be included for multi-line display, for instance date on one
line and the time below it.  The various C<Gtk2::Label> and C<Gtk2::Misc>
properties can control centring.  For example,

    my $clock = Gtk2::Ex::Clock->new (format  => "%d %b\n%H:%M",
                                      justify => 'center',
                                      xalign  => 0.5);

=item C<timezone> (string or C<DateTime::TimeZone>, default local time)

The timezone to use in the display.  An empty string or undef (the default)
means local time.

For a string, the C<TZ> environment variable (C<$ENV{'TZ'}>) is set to
format the time (and restored so other parts of the program are not
affected).  See the C<tzset> man page or the GNU C Library manual under "TZ
Variable" for possible settings.

For a C<DateTime::TimeZone> object its information and a C<DateTime> object
C<strftime> is used for the display.  The C<strftime> method may have extra
conversions over what the C library offers.

=item C<resolution> (integer, default from format)

The resolution, in seconds, of the clock.  The default 0 means look at the
format to decide whether seconds is needed or minutes is enough.  Formats
using C<%S> and various other mostly-standard forms like C<%T> and C<%X> are
recognised as seconds, as are C<DateTime> methods like C<%{iso8601}>.
Anything else is minutes.  If that comes out wrong you can force it by
setting this property.

Incidentally, if you're only displaying hours then you probably don't want
hour resolution, since a system time change won't be recognised until the
requested resolution worth of real time has elapsed.

=back

The properties of C<Gtk2::Label> and C<Gtk2::Misc> will variously control
padding, alignment, etc.  See the F<examples> directory in the sources for
some complete programs displaying clocks in various forms.

=head1 LOCALIZATIONS

For a string C<timezone> property the C<POSIX::strftime> function gets
localized day names etc from C<LC_TIME> in the usual way.  Generally Perl
does a suitable C<setlocale(LC_TIME)> at startup so the usual settings take
effect automatically.

For a C<DateTime::TimeZone> object the DateTime C<strftime> gets
localizations from the C<< DateTime->DefaultLocale >> (see L<DateTime>).
Generally you must make a call to set C<DefaultLocale> yourself at some
point early in the program.

The C<format> string can include unicode in Perl's usual wide-char fashion.
Currently for C<POSIX::strftime> it's converted to the locale charset then
back again, so you'll be limited to what's representable in the locale
charset.  For C<DateTime::TimeZone> all characters can be used irrespective
of the locale.

=head1 IMPLEMENATION

The clock is implemented by updating a C<Gtk2::Label> under a timer.  This
is simple, and makes good use of the label widget's text drawing code, but
it does mean that in a variable-width font the size of the widget can change
as the time changes.  For minutes display any resizes are hardly noticable,
but for seconds it may be best to have a fixed-width font, or to
C<set_size_request> a fixed size (initial size plus a few pixels say), or
even try a NoShrink (see L<Gtk2::Ex::NoShrink>).

The way C<TZ> is temporarily changed to implement a non-local timezone could
be slightly on the slow side.  The GNU C Library (as of version 2.7) for
instance opens and re-reads a zoneinfo file on each change.  Doing that
(twice) each minute is fine, but for seconds you may prefer
C<DateTime::TimeZone>.  Changing C<TZ> probably isn't thread safe either,
though rumour has it you have to be extremely careful with threads and
Gtk2-Perl anyway, so you probably won't be using threads.  Again you can use
a C<DateTime::TimeZone> object if you're nervous.

=head1 SEE ALSO

C<strftime(3)>, C<tzset(3)>, L<Gtk2>, L<Gtk2::Label>, L<Gtk2::Misc>,
L<DateTime::TimeZone>, L<DateTime>

=head1 HOME PAGE

L<http://www.geocities.com/user42_kevin/gtk2-ex-clock/index.html>

=head1 LICENSE

Gtk2-Ex-Clock is Copyright 2007, 2008, 2009 Kevin Ryde

Gtk2-Ex-Clock is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 3, or (at your option) any later
version.

Gtk2-Ex-Clock is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
Gtk2-Ex-Clock.  If not, see L<http://www.gnu.org/licenses/>.

=cut
