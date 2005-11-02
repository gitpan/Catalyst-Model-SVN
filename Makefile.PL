# $Id: Makefile.PL 909 2005-11-02 00:57:06Z claco $
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
        'SVN::Core'   => 0,
        'IO::Scalar'  => 0,
        'Path::Class' => 0,
        'DateTime'    => 0
    },
    (ExtUtils::MakeMaker->VERSION >= 6.11) ?
    (NO_META => 1) : (),
    dist => {
        PREOP => 'pod2text lib/Catalyst/Model/SVN.pm > $(DISTVNAME)/README',
    }
);
