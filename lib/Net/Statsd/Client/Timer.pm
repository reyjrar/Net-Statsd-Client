package Net::Statsd::Client::Timer;
use Moo;
use Sub::Quote;

# ABSTRACT: Measure event timings and send them to StatsD
# VERSION
# AUTHORITY

use Time::HiRes qw(gettimeofday tv_interval);

has 'statsd' => (
  is => 'ro',
  required => 1,
);

has '_pending' => (
  is => 'rw',
  default => quote_sub q{1},
);

has ['metric', 'start', '_file', '_line'] => (
  is => 'rw',
);

sub BUILD {
  my ($self) = @_;
  my (undef, $file, $line) = caller(1);

  $self->start([gettimeofday]);
  $self->_file($file);
  $self->_line($line);
}

sub finish {
  my ($self) = @_;
  my $duration = tv_interval($self->{start});
  $self->{statsd}->timing_ms(
    $self->{metric},
    $duration * 1000,
    $self->{sample_rate},
  );
  delete $self->{_pending};
}

sub cancel {
  my ($self) = @_;
  delete $self->{_pending};
}

sub DEMOLISH {
  my ($self) = @_;
  if ($self->{_pending}) {
    my $metric = $self->{metric};
    $metric = $self->{statsd}{prefix} . $metric if $self->{statsd} && $self->{statsd}{prefix};
    warn "Unfinished timer for stat $metric (created at $self->{_file} line $self->{_line})";
  }
}

1;

__END__

=head1 SYNOPSIS

    use Net::Statsd::Client;
    my $stats = Net::Statsd::Client->new(prefix => "service.frobnitzer.");

    my $timer = $stats->timer("request_duration");
    # ... do something expensive ...
    $timer->finish;

=head1 METHODS

=head2 Net::Statsd::Client::Timer->new(...)

To build a timer object, call L<Net::Statsd::Client>'s C<timer> method,
instead of calling this constructor directly.

A timer has an associated statsd object, metric name, and sample rate, and
begins counting as soon as it's constructed.

=head2 $timer->finish

Stop timing, and send the elapsed time to the server.

=head2 $timer->cancel

Stop timing, but do not send the elapsed time to the server. A timer that
goes out of scope without having C<finish> or C<cancel> called on it will
generate a warning, since this probably points to bugs and lost timing
information.
