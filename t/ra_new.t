use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use Catalyst::Model::SVN;
use Scalar::Util qw(blessed);

my @args;
{
    no warnings 'redefine';
    *SVN::Ra::new = sub {
        @args = @_;
    };
};

throws_ok { Catalyst::Model::SVN->new() } qr/repository/, 'Throws with no config';
Catalyst::Model::SVN->config(
    repository => 'http://www.test.com/svn/repos/',
);
lives_ok {Catalyst::Model::SVN->new()} 'Can construct';
ok(scalar(@args), 'Has args');
my $self = shift(@args);
my %p = @args;
ok($p{pool}->isa('SVN::Pool'), 'Have an SVN::Pool arg');
ok(!blessed($p{url}), 'url not blessed');
