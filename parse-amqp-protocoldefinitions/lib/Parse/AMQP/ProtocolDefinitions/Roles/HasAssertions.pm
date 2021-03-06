package Parse::AMQP::ProtocolDefinitions::Roles::HasAssertions;

use Moose::Role;
use Parse::AMQP::ProtocolDefinitions::Assert;

has assertions => (
  isa     => 'ArrayRef',
  is      => 'rw',
  default => sub { [] },
);

after extract_from => sub {
  my ($self, $elem) = @_;

  $self->assertions(
    Parse::AMQP::ProtocolDefinitions::Assert->parse_all(
      $elem, parent => $self
    )
  );
};

no Moose::Role;

1;
