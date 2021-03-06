#!perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

require 't/tlib/load_specs.pl';
my @specs = load_specs();
plan skip_all => 'No active specs found in $ENV{AMQP_PROTO_DEFS_DIR}'
  unless @specs;

SPEC: for my $spec (@specs) {
  my $amqp;
  lives_ok sub {
    $amqp = Parse::AMQP::ProtocolDefinitions->load($spec->{path});
  }, "Loading spec $spec->{name} from '$spec->{path}'";
  next SPEC unless $amqp;

  my $cs = $amqp->classes;
  ok($cs);
  is(scalar(keys %$cs), $spec->{t_classes});

  my $c = $cs->{'channel'};
  ok($c);
  is($c->name,  'channel');
  is($c->index, 20);
  is($c->label, 'work with channels');
  like($c->doc,
    qr/channel class provides methods for a client to establish a channel/);
  like($c->doc('grammar'), qr/close-channel\s+= C:CLOSE S:CLOSE-OK/);
  is($c->parent, $amqp, "... not parentless, I like having a father");
  is(
    $c->sys,
    'Parse::AMQP::ProtocolDefinitions',
    '... but my sys is still the proper one'
  );

  my $chs = $c->chassis;
  ok($chs);
  is(ref($chs),          'HASH');
  is(scalar(keys %$chs), 2);
  ok(exists $chs->{$_}) for (qw( client server ));
  for my $ch (values %$chs) {
    isa_ok(
      $ch,
      'Parse::AMQP::ProtocolDefinitions::Chassis',
      'Chassis is of proper type'
    );
    is($ch->implement, 'MUST',  '... and it MUST be implemented');
    is($ch->parent,    $c,      "... not parentless, I like having a father");
    is($ch->sys,       $c->sys, '... but my sys is still the proper one');
  }

  my $cms = $c->methods;
  ok($cms);
  is(ref($cms), 'HASH');

  my (@all_methods, @sync_methods);
  if ($spec->{name} eq 'amqp-0.9.1') {
    @all_methods  = qw( open open-ok close close-ok flow flow-ok );
    @sync_methods = qw( open open-ok close close-ok flow );
  }
  else {
    @all_methods = qw(
      open open-ok close close-ok flow flow-ok
      ok resume pong ping
    );
    @sync_methods = qw( open open-ok close close-ok flow );
  }

  is(scalar(keys %$cms), scalar(@all_methods));
  ok(exists $cms->{$_}) for (@all_methods);
  for my $cm (values %$cms) {
    isa_ok(
      $cm,
      'Parse::AMQP::ProtocolDefinitions::Method',
      'Method is of proper type'
    );
    is($cm->parent, $c,      "... not parentless, I like having a father");
    is($cm->sys,    $c->sys, '... but my sys is still the proper one');
  }
  ok($cms->{$_}->synchronous, "method '$_' is synchronous")
    for (@sync_methods);
  ok(!$cms->{'flow-ok'}->synchronous, "method 'flow-ok' is NOT synchronous");

  my $m = $cms->{open};
  ok($m);
  is($m->index, 10);
  is($m->label, 'open a channel for use');
  like($m->doc, qr/This method opens a channel to the server/);

  my $rs = $m->rules;
  ok($rs);
  is(scalar(keys %$rs), 1);
  my $r = $rs->{state};
  isa_ok($r, 'Parse::AMQP::ProtocolDefinitions::Rule');
  is($r->name,       'state');
  is($r->on_failure, 'channel-error');
  like($r->doc, qr/The client MUST NOT use this method on an already/);
  like($r->doc('scenario'), qr/Client opens a channel and then reopens/);
  is($r->parent, $m,      "... not parentless, I like having a father");
  is($r->sys,    $m->sys, '... but my sys is still the proper one');

  for my $mn (qw( open open-ok close close-ok flow flow-ok )) {
    $m   = $cms->{$mn};
    $chs = $m->chassis;
    ok($chs, "Got chassis for method $mn");
    is(ref($chs), 'HASH', '... proper type');

    my @sides;
    push @sides, 'client' unless $mn eq 'open';
    push @sides, 'server' unless $mn eq 'open-ok';

    is(scalar(keys %$chs), scalar(@sides), '... correct number of chasiss');
    foreach my $side (@sides) {
      ok(exists $chs->{$side}, "... on the correct side $side");
      my $ch = $chs->{$side};
      isa_ok(
        $ch,
        'Parse::AMQP::ProtocolDefinitions::Chassis',
        '... proper type $ch'
      );
      is($ch->implement, 'MUST', '... and expected implement attr value');
      is($ch->parent, $m,      "... not parentless, I like having a father");
      is($ch->sys,    $m->sys, '... but my sys is still the proper one');
    }

    $rs = $m->responses;
    ok($rs);
    is(ref($rs), 'HASH');
    my ($r) = values %$rs;
    if ($mn !~ /-ok$/) {
      is(keys %$rs, 1);
      ok($r, "Method $mn has a response");
      isa_ok(
        $r,
        'Parse::AMQP::ProtocolDefinitions::Response',
        '... of the proper type'
      );
      is($r->name, "${mn}-ok", '... and with the expected name (${mn}-ok)');
      is($r->parent, $m,      "... not parentless, I like having a father");
      is($r->sys,    $m->sys, '... but my sys is still the proper one');
    }
    else {
      ok(!defined($r), '... and no response');
    }
  }

  $c = $cs->{basic};
  ok($c, 'Got class basic');
  $m = $c->methods->{get};
  ok($m, '... and method get');
  $rs = $m->responses;
  ok($rs, '... have method get responses');
  is(scalar(keys %$rs), 2, '... two responses, as expected');
  for my $rn (qw( get-ok get-empty )) {
    ok(exists $rs->{$rn}, "...... the '$rn' response is here");
    isa_ok(
      $rs->{$rn},
      'Parse::AMQP::ProtocolDefinitions::Response',
      '...... and of the proper type'
    );
  }

  my $fs = $m->fields;
  ok($fs, "Got fields for method basic.get");
  is(ref($fs),     'ARRAY', '... proper type for field set');
  is(scalar(@$fs), 3,       '... correct (3) number of fields');
  isa_ok(
    $_,
    'Parse::AMQP::ProtocolDefinitions::Field',
    '... field ' . $_->name
  ) for (@$fs);

  if ($spec->{version} le '000009000') {
    is($fs->[0]->name, 'ticket', "Field 'ticket' with proper name");
    ok(!$fs->[0]->reserved, '... it is not a reserved field');
    is($fs->[0]->domain, 'access-ticket',
      '... so with a domain, access-ticket');
    ok(!$fs->[0]->label, '... but no label on this one');
    ok(!$fs->[0]->type,  '... and no type');
    ok(!$fs->[0]->doc,   '... and with no docs');
  }
  else {
    is($fs->[0]->name, 'reserved-1', 'Field reserved-1 with proper name');
    ok($fs->[0]->reserved, '... it is a reserved field');
  }
  ok(!$fs->[0]->label, '... and without a label');

  is($fs->[1]->name, 'queue', 'Field queue with proper name');
  ok(!$fs->[1]->reserved, '... it is not a reserved field');
  is($fs->[1]->domain, 'queue-name', '... so with a domain, queue-name');
  ok(!$fs->[1]->label, '... but no label on this one');
  ok(!$fs->[1]->type,  '... and no type');
  like(
    $fs->[1]->doc,
    qr/Specifies the name of the queue to (consume|get a message) from/,
    '... although we get docs'
  );

  is($fs->[2]->name, 'no-ack', 'Field no-ack with proper name');
  ok(!$fs->[2]->reserved, '... it is not a reserved field');
  is($fs->[2]->domain, 'no-ack', '... so with a domain, no-ack');
  ok(!$fs->[2]->label, '... but no label for this one');
  ok(!$fs->[2]->type,  '... and no type');
}

done_testing();
