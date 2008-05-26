# $Id: /mirror/claco/Catalyst-Model-SVN/trunk/Makefile.PL 4827 2008-05-26T08:51:36.007490Z bobtfish  $
use ExtUtils::MakeMaker;
use 5.008;
use strict;
use warnings;

WriteMakefile(
    NAME         => 'Catalyst::Model::SVN',
    VERSION_FROM => 'lib/Catalyst/Model/SVN.pm',
    AUTHOR       => 'Christopher H. Laco <claco@chrislaco.com>, Tomas Doran <bobtfish@bobtfish.net>',
    ABSTRACT     => 'Catalyst Model to browse Subversion repositories',
    PREREQ_PM    => {
        'Catalyst::Runtime'     => 0,
        'Catalyst::Devel'       => 0, # Build dep
        'SVN::Core'             => 0,
        'IO::Scalar'            => 0,
        'Path::Class'           => 0,
        'DateTime'              => 0,
        'IO::Scalar'            => 0,
    },
    (ExtUtils::MakeMaker->VERSION >= 6.11) ?
    (NO_META => 1) : (),
    dist => {
        PREOP => 'pod2text lib/Catalyst/Model/SVN.pm > $(DISTVNAME)/README',
    },
    clean => { FILES => 't/TestApp'},
);
