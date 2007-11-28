#!perl -w
# $Id: /mirror/claco/Catalyst-Model-SVN/tags/0.06/t/pod_spelling.t 736 2007-11-28T01:17:49.720742Z bobtfish  $
use strict;
use warnings;
use Test::More;

eval 'use Test::Spelling 0.11';
plan skip_all => 'Test::Spelling 0.11 not installed' if $@;
plan skip_all => 'set TEST_SPELLING to enable this test' unless $ENV{TEST_SPELLING};

set_spell_cmd('aspell list');

add_stopwords(<DATA>);

all_pod_files_spelling_ok();

__DATA__
SVN
uri
propget
versioned
