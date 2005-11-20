# $Id: Makefile.PL 948 2005-11-19 23:52:57Z claco $
use ExtUtils::MakeMaker;
use 5.008;
use strict;
use warnings FATAL => 'all';

WriteMakefile(
    NAME         => 'Catalyst::Model::SVN',
    VERSION_FROM => 'lib/Catalyst/Model/SVN.pm',
    AUTHOR       => 'Christopher H. Laco <claco@chrislaco.com>',
    ABSTRACT     => 'Catalyst Model to browse Subversion repositories',
    PREREQ_PM    => {
        'Catalyst'    => 5.33,
        'SVN::Core'   => 0,
        'IO::Scalar'  => 0,
        'Path::Class' => 0,
        'DateTime'    => 0
    },
    (ExtUtils::MakeMaker->VERSION >= 6.11) ?
    (NO_META => 1) : (),
    dist => {
        PREOP => 'pod2text lib/Catalyst/Model/SVN.pm > $(DISTVNAME)/README',
    },
    clean => { FILES => 't/TestApp'},
);
