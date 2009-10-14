package Parse::AMQP::ProtocolDefinitions::Domain;

use Moose;
use Parse::AMQP::ProtocolDefinitions::Rule;

with
  'Parse::AMQP::ProtocolDefinitions::Roles::ParseUnique',
  'Parse::AMQP::ProtocolDefinitions::Roles::HasNameAsID',
  'Parse::AMQP::ProtocolDefinitions::Roles::HasValidAttrs',
  'Parse::AMQP::ProtocolDefinitions::Roles::HasDocumentation';


has type => (
  isa => 'Str',
  is  => 'rw',
);

has label => (
  isa => 'Str',
  is  => 'rw',
);

has rules => (
  isa     => 'HashRef',
  is      => 'rw',
  default => sub { {} },
);


no Moose;
__PACKAGE__->meta->make_immutable;


##############################

sub xpath_expr  {'/amqp/domain'}
sub valid_attrs {qw( type label)}

##############################

sub parse {
  my ($self, $elem) = @_;

  $self->rules(Parse::AMQP::ProtocolDefinitions::Rule->parse_all($elem));
}

1;
