package Protocol::AMQP::Util;

use strict;
use warnings;
use parent qw( Exporter );
use Carp qw( confess );

@Protocol::AMQP::Util::EXPORT_OK = qw(
  extract_table
);

##################################

sub extract_table;    ## Forward decl

my %type_table = (
  'V' => [''],

  't' => ['C',  1],
  'b' => ['C',  1],
  'B' => ['C',  1],
  'U' => ['n',  2],
  'u' => ['n',  2],
  'I' => ['N',  4],
  'i' => ['N',  4],
  'L' => ['NN', 8],
  'l' => ['NN', 8],
  'T' => ['NN', 8],

  'S' => ['N/a', -4],
  's' => ['C/a', -1],

  'F' => ['N/a', \&extract_table],  
);

sub extract_table {
  my ($buf) = @_;
  my %table;

  while ($buf) {
    my ($name, $t) = unpack("C/a a", $buf);

    my $offset = length($name) + 2;
    my $value;

    ## TODO: fix signed values
    ## TODO: implement field-array - how to reuse this next table?

    confess("AMQP: invalid table field-value '$t'")
      unless exists $type_table{$t};

    my $rule = $type_table{$t};
    my ($format, $delta) = @$rule;
    
    if ($format) {
      my @v = unpack($format, substr($buf, $offset));
      if   (@v > 1) { $value = \@v }
      else          { $value = $v[0] }
      
      if (ref $delta) {
        $offset += length($value);
        $value = $delta->($value);
      }
      elsif ($delta < 0) {
        $offset += length($value) - $delta;
      }
      else {
        $offset += $delta;
      }
    }

    $table{$name} = { $t => $value };
    substr($buf, 0, $offset, '');
  }

  ## TODO: validate fields, connection exception if not valid (see 4.2.5.5)

  return \%table;
}

##################################

use Data::Dump ();

sub _trace {
  my ($line) = (caller(0))[2];
  my ($sub)  = (caller(1))[3];

  my @args;
  foreach my $arg (@_) {
    if (my $type = ref $arg) {
      if ($type eq 'SCALAR') {
        my $partial = $$arg;
        my $len = length($partial);
        substr($partial, 45, $len, '...')        if $len > 45;
        push @args, Data::Dump::pp(\$partial), " (len $len)";
        next;
      }
      
      $arg = Data::Dump::pp($arg);
    }
    push @args, $arg;
  }
  
  my $pad = ' ';
  foreach my $l (split(/\015?\012/, join('', @args))) {
    print STDERR "# [$sub:$line]$pad$l\n";
    $pad = '+   ';
  }

  return;
}

1;