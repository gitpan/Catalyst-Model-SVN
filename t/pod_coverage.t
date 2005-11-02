#!perl -wT
# $Id: pod_coverage.t 909 2005-11-02 00:57:06Z claco $
use strict;
use warnings;
use Test::More;

eval 'use Test::Pod::Coverage 1.04';
plan skip_all => 'Test::Pod::Coverage 1.04' if $@;

eval 'use Pod::Coverage 0.14';
plan skip_all => 'Pod::Coverage 0.14 not installed' if $@;

my $trustme = {
    trustme =>
    [qr/^(stringify|new)$/]
};

all_pod_coverage_ok($trustme);
