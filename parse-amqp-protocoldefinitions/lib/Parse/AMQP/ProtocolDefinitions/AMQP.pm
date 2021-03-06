package Parse::AMQP::ProtocolDefinitions::AMQP;

use Moose;
use Parse::AMQP::ProtocolDefinitions::Class;
use Parse::AMQP::ProtocolDefinitions::Constant;
use Parse::AMQP::ProtocolDefinitions::Domain;
use Path::Class qw( dir );

extends 'Parse::AMQP::ProtocolDefinitions::Base';

has major => (
  isa => 'Int',
  is  => 'rw',
);

has minor => (
  isa => 'Int',
  is  => 'rw',
);

has revision => (
  isa => 'Int',
  is  => 'rw',
);

has port => (
  isa => 'Int',
  is  => 'rw',
);

has comment => (
  isa => 'Str',
  is  => 'rw',
);

has constants => (
  isa     => 'HashRef',
  is      => 'rw',
  default => sub { {} },
);

has domains => (
  isa     => 'HashRef',
  is      => 'rw',
  default => sub { {} },
);

has classes => (
  isa     => 'HashRef',
  is      => 'rw',
  default => sub { {} },
);

with 'Parse::AMQP::ProtocolDefinitions::Roles::HasValidAttrs';

no Moose;
__PACKAGE__->meta->make_immutable;

###################################

sub xpath_expr  {'amqp'}
sub valid_attrs {qw(major minor revision port comment)}

###################################

sub extract_from {
  my ($self, $elem) = @_;

  $self->constants(
    Parse::AMQP::ProtocolDefinitions::Constant->parse_all(
      $elem, parent => $self
    )
  );
  $self->domains(
    Parse::AMQP::ProtocolDefinitions::Domain->parse_all(
      $elem, parent => $self
    )
  );
  $self->classes(
    Parse::AMQP::ProtocolDefinitions::Class->parse_all(
      $elem, parent => $self
    )
  );
}


###################################

sub generate_all_files {
  my $self   = shift;
  my $prefix = shift;
  my $dir    = dir(@_);

  $self->generate($prefix, $dir);

  $dir = $dir->subdir($self->package_basename);
  $dir->mkpath;

  for my $class (values %{$self->classes}) {
    $class->generate($prefix, $dir);
  }

  return;
}

sub generate {
  my $self   = shift;
  my $prefix = shift;
  my $dir    = dir(@_);

  my $fh = $dir->file($self->package_filename)->openw;
  $fh->print($self->build_version_class($prefix));
  $fh->close;

  return;
}

sub build_version_class {
  my ($self, $prefix) = @_;

  my ($major, $minor, $rev) = ($self->major, $self->minor, $self->revision);
  my $package = $self->package($prefix);

  ## Start the package
  my $buf = <<EOH;
package $package;

use Moose;
extends 'Protocol::AMQP::API::Version';

## My version registration
use Protocol::AMQP::Registry;

Protocol::AMQP::Registry->register_version(
  { major    => $major,
    minor    => $minor,
    revision => $rev,

    api => '$package',
  }
);

## My API classes
EOH

  my $classes = $self->classes;
  for my $class (sort { $a->index <=> $b->index } values %$classes) {
    $buf .= $class->build_class_slot($package);
  }

  ## End the package
  $buf .= "1;\n";

  # TODO: generate POD

  return $buf;
}

sub package_basename {
  my ($self) = @_;

  return
    sprintf('V%0.3d%0.3d%0.3d', $self->major, $self->minor, $self->revision);
}

sub package {
  my $self = shift;
  return join('::', @_, $self->package_basename);
}

1;
