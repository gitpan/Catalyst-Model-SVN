# $Id: /mirror/claco/Catalyst-Model-SVN/tags/0.06/Makefile.PL 713 2005-11-19T23:52:57.264953Z claco  $
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
