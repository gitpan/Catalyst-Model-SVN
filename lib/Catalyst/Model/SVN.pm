# $Id: SVN.pm 1213 2006-06-18 20:42:22Z claco $
package Catalyst::Model::SVN;
use strict;
use warnings;
use SVN::Core;
use SVN::Client;
use SVN::Ra;
use IO::Scalar;
use URI;
use Path::Class;
use NEXT;
use DateTime;
use base 'Catalyst::Base';

our $VERSION = '0.05';

__PACKAGE__->config(
    revision => 'HEAD'
);

sub new {
    my ($self, $c) = @_;
    $self = $self->NEXT::new(@_);

    $self->config->{'client'} =
        SVN::Client->new(auth => [SVN::Client::get_simple_provider()]),

    $self->config->{'ra'} =
        SVN::Ra->new($self->config->{'repository'});

    return $self;
};

sub revision {
    my $self = shift;
    my $ra = $self->config->{'ra'};

    return $ra->get_latest_revnum();
};

sub repository {
    my $self = shift;

    return $self->config->{'repository'};
};

sub ls {
    my ($self, $path, $revision) = @_;
    my $uri = URI->new($self->repository);
    my $fullpath = dir($uri->path, ($path || '/'))->as_foreign('Unix');
    $uri->path($fullpath);

    $revision ||= $self->config->{'revision'};

    my @nodes;

    eval {
        my $items = $self->config->{'client'}->ls($uri->as_string, $revision, 0);

        @nodes = map {
            Catalyst::Model::SVN::Item->new({
                name => $_,
                item => $items->{$_},
                repository => $self,
                path => $path,
                uri  => $uri->as_string
            })
        } sort keys %{$items};
    };

    if (wantarray) {
        return @nodes;
    } else {
        return \@nodes;
    };
};

sub cat {
    my ($self, $path, $revision) = @_;
    my $client = $self->config->{'client'};
    my $file = IO::Scalar->new;
    my $requested_path = $path;

    eval {
        $client->cat($file, $path, $revision);
    };
    if ($@) {
        $path = $self->_resolve_copy($path, $revision);

        if ($path ne $requested_path) {
            $client->cat($file, $path, $revision);
        } else {
            die $@;
        };
    };

    $file =~ s/^\s+//g;
    $file =~ s/\s+$//g;

    return $file;
};

sub _resolve_copy {
    my ($self, $path, $revision) = @_;
    my $client = $self->config->{'client'};
    my $copyfrom;

    $client->log([$path], 'HEAD', $revision, 1, 1, sub{
        return if $copyfrom;

        my ($changes, $revision, $author, $date, $message) = @_;

        if ($changes && scalar keys %{$changes}) {
            foreach my $change (keys %{$changes}) {
                my $obj = $changes->{$change};
                my $action = $obj->action;
                $copyfrom = $obj->copyfrom_path;

                if ($obj->action eq 'A' && $copyfrom) {
                     $path =~ s/$change/$copyfrom/;

                    last;
                };
            };
        };
    });

    return $path;
};

package Catalyst::Model::SVN::Item;
use strict;
use warnings;
use Path::Class;
use SVN::Core;
use SVN::Client;
use DateTime;
use overload '""' => \&stringify, fallback => 1;

sub new {
    my ($class, $args) = @_;
    my $self = bless $args, $class;

    return $self;
};

sub author {
    return shift->{'item'}->last_author;
};

sub name {
    return shift->{'name'};
};

sub is_directory {
    my $self = shift;
    my $kind = $self->kind;

    return $kind == $SVN::Node::dir ? 1 : 0 ;
};

sub is_file {
    my $self = shift;
    my $kind = $self->kind;

    return $kind == $SVN::Node::file ? 1 : 0 ;
};

sub kind {
    return shift->{'item'}->kind;
};

sub contents {
    my $self = shift;

    if ($self->is_file) {
        return $self->{'repository'}->cat(
            ($self->{'realpath'} || $self->uri), $self->revision);
    } else {
        return;
    };
};

sub path {
    my $self = shift;
    my $path = $self->{'path'};
    my $name = $self->name;

    if (!($self->is_file && $path =~ /$name$/)) {
        $path = $path ? $path . '/' . $self->name : $self->name;
    };

    return $path;
};

sub realpath {
    my $self = shift;

    return $self->{'realpath'};
};

sub uri {
    my $self = shift;
    my $uri = $self->{'uri'};
    my $name = $self->name;

    if (!($self->is_file && $self->{'path'} =~ /$name$/)) {
        return $uri . '/' . $self->name;
    } else {
        return $uri;
    };
};

sub log {
    my $self = shift;
    my $item = $self->{'item'};
    my $client = $self->{'repository'}->config->{'client'};

    eval {
        $client->log(
            [$self->uri],
            $self->revision,
            $self->revision,
            0,
            0,
            sub {
                my ($changes, $revision, $author, $date, $message) = @_;

                $self->{'log'} = $message;
            }
        );
    };
    if ($@) {
        my $path = $self->{'repository'}->_resolve_copy($self->uri, $self->revision);

        if ($path ne $self->uri) {
            $client->log(
                [$path],
                $self->revision,
                $self->revision,
                0,
                0,
                sub {
                    my ($changes, $revision, $author, $date, $message) = @_;

                    $self->{'log'} = $message;
                }
            );
        } else {
            die $@;
        };
    };
    return $self->{'log'};
};

sub size {
    return shift->{'item'}->size;
};

sub time {
    my $self = shift;
    my $time = DateTime->from_epoch(
        epoch => substr($self->{'item'}->time, 0, 10)
    );

    $time->add_duration(
        DateTime::Duration->new(nanoseconds => substr($self->{'item'}->time, 10))
    );

    $time->set_time_zone('UTC');

    return $time;
};

sub revision {
    return shift->{'item'}->created_rev;
};

sub stringify {
    my $self = shift;

    return $self->{'name'};
};

1;
__END__

=head1 NAME

Catalyst::Model::SVN - Catalyst Model to browse Subversion repositories

=head1 SYNOPSIS

    # Model
    __PACKAGE__->config(
        repository => '/path/to/svn/root/or/path'
    );

    # Controller
    sub default : Private {
        my ($self, $c) = @_;
        my $path = join('/', $c->req->args);
        my $revision = $c->req->param('revision') || 'HEAD';

        $c->stash->{'repository_revision'} = MyApp::M::SVN->revision;
        $c->stash->{'items'} = MyApp::M::SVN->ls($path, $revision);

        $c->stash->{'template'} = 'blog.tt';
    };

=head1 DESCRIPTION

This model class uses the perl-subversion bindings to access a Subversion
repository and list items and view their contents. It is currently only a
read-only client but may expand to be a fill fledged client at a later time.

=head1 CONFIG

The following configuration options are available:

=head2 repository

This is the full path to the root of, or any directory in your Subversion
repository. This can be one of http://, svn://, or file:/// schemes.

=head2 revision

This is the default revision to use when no revision is specified. By default,
this will be C<HEAD>.

=head1 METHODS

=head2 cat($path [, $revision])

Returns the contents of the path specified. If C<path> is a copy, the logs are
transversed to find original. The request is then reissued for the original path
for the C<revision> specified.

=head2 ls($path [, $revision])

Returns a array of C<Catalyst::Model::SVN::Item> objects in list context, each
representing an entry in the specified repository path. In scalar context, it
returns an array reference.  If C<path> is a copy, the logs are
transversed to find the original. The request is then reissued for the original
path for the C<revision> specified.

Each C<Catalyst::Model::SVN::Item> object has the following methods:

=over

=item author

The author of the latest revision of the current item.

=item contents

The contents of the of the current item. This is the same as
calling C<Catalyst::Model::SVN->cat($item->uri, $item->revision)

=item is_directory

Returns 1 if the current item is a directory; 0 otherwise.

=item is_file

Returns 1 if the current item is a file; 0 otherwise.

=item kind

Returns the kind  of the current item. See L<SVN::Core> for the possible types,
usually $SVN::Node::path or $SVN::Node::file.

=item log

Returns the last log entry for the current item. Be forewarned, this makes an
extra call to the repository, which is slow. Only use this if you are listing a
single item, and not when looping through large collections of items. If the
current item is a copy, the logs are transversed to find the original. The
request is then reissued for the original path for the C<revision> specified.

=item name

Returns the name of the current item.

=item path

Returns the path of the current item relative to the repository root.

=item revision

Returns the revision of the current item.

=item size

Returns the raw file size in bytes for the current item.

=item time

Returns the last modified time of the current item as a L<DateTime> object.

=item uri

Returns the full repository path of the current item.

=back

=head2 repository

Returns the repository specified in the configuration C<repository> option.

=head2 revision

Returns the latest revisions of the repository you are connected to.

=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Helper>, L<SVN::Client>, L<SVN::Ra>

=head1 AUTHOR

    Christopher H. Laco
    CPAN ID: CLACO
    claco@chrislaco.com
    http://today.icantfocus.com/blog/
