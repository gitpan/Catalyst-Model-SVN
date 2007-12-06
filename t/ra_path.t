use strict;
use warnings;
use Catalyst::Model::SVN;
use Test::More tests => 8;
use Test::Exception;

my $repos_uri = 'http://www.bobtfish.net/svn/repos/';
lives_ok {
    Catalyst::Model::SVN->config(
        repository => $repos_uri,
    );
} 'Setting repos config';

my $m;
lives_ok { $m = Catalyst::Model::SVN->new(); } 'Can construct';

is($m->_ra_path( '/' ), '/svn/repos/', 'Root dir /');
is($m->_ra_path( '/README' ), '/svn/repos/README', '/README is correct');
is($m->_ra_path( '//README' ), '/svn/repos/README', '//README is correct');

is($m->_ra_path( $repos_uri ), '/svn/repos/', 'full URI Root dir /');
is($m->_ra_path( $repos_uri . 'README' ), '/svn/repos/README', 'full URI /README is correct');
is($m->_ra_path( $repos_uri . '/README' ), '/svn/repos/README', 'full URI //README is correct');


