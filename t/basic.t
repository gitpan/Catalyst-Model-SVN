#!perl -wT
# $Id: /mirror/claco/Catalyst-Model-SVN/tags/0.09/t/basic.t 694 2005-11-02T00:57:06.696032Z claco  $
use strict;
use warnings;
use Test::More tests => 2;

BEGIN {
    use_ok('Catalyst::Model::SVN');
    use_ok('Catalyst::Helper::Model::SVN');
};
