package Parse::AMQP::ProtocolDefinitions::Roles::HasRules;

use Moose::Role;
use Parse::AMQP::ProtocolDefinitions::Rule;

has rules => (
  isa     => 'HashRef',
  is      => 'rw',
  default => sub { {} },
);

after parse => sub {
  my ($self, $elem) = @_;

  $self->rules(Parse::AMQP::ProtocolDefinitions::Rule->parse_all($elem));
};

no Moose::Role;

1;
