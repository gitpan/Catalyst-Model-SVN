#!perl -wT
# $Id: basic.t 909 2005-11-02 00:57:06Z claco $
use strict;
use warnings;
use Test::More tests => 2;

BEGIN {
    use_ok('Catalyst::Model::SVN');
    use_ok('Catalyst::Helper::Model::SVN');
};
