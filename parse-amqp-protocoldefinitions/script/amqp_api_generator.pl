#!/usr/bin/env perl

use strict;
use warnings;
use Parse::AMQP::ProtocolDefinitions;

Parse::AMQP::ProtocolDefinitions->load(shift)->generate_all_files(@ARGV);
