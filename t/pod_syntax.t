#!perl -wT
# $Id: pod_syntax.t 909 2005-11-02 00:57:06Z claco $
use strict;
use warnings;
use Test::More;

eval 'use Test::Pod 1.00';
plan skip_all => 'Test::Pod 1.00 not installed' if $@;

all_pod_files_ok();
