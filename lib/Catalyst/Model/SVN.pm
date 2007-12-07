# $Id: /mirror/claco/Catalyst-Model-SVN/tags/0.09/lib/Catalyst/Model/SVN.pm 766 2007-12-07T11:43:20.989565Z bobtfish  $
package Catalyst::Model::SVN;
use strict;
use warnings;
use SVN::Core;
use SVN::Ra;
use IO::Scalar;
use URI;
use Path::Class qw( dir file );
use NEXT;
use DateTime;
use Catalyst::Model::SVN::Item;
use Scalar::Util qw/blessed/;
use Carp qw/confess croak/;
use base 'Catalyst::Base';

our $VERSION = '0.09';

__PACKAGE__->config( revision => 'HEAD' );

sub new {
    my ( $self, $c ) = @_;
    $self = $self->NEXT::new(@_);

    my $root_pool = SVN::Pool->new_default;
    my $ra        = SVN::Ra->new(
        url  => $self->repository,
        auth => undef,
        pool => $root_pool
    );
    $self->{pool} = $root_pool;
    $self->{ra}   = $ra;

    return $self;
}

sub _ra {
    my $self = shift;
    confess('Need an instance') unless blessed $self;
    return $self->{ra};
}

sub revision {
    my $self    = shift;
    my $subpool = SVN::Pool::new_default_sub;
    return $self->_ra->get_latest_revnum();
}

sub repository {
    my ($self) = @_;

    return $self->{repos} if $self->{repos};

    my $repos = $self->config->{repository};
    confess('No configured repository!') unless defined $repos;

    return $self->{repos} = URI->new($repos);
}

sub ls {
    my ( $self, $path, $revision ) = @_;
    
    $revision ||= $self->config->{revision};
    if ( $revision eq 'HEAD' ) {
        $revision = $SVN::Core::INVALID_REVNUM;
    }
    my $subpool = SVN::Pool::new_default_sub;

    my @nodes;
    my ( $dirents, $revnum, $props )
        = $self->_ra->get_dir( _ra_path( $self, $path ), $revision );

# Note that simple data which comes back here is ok, but the dirents data structure
# will be magically deallocated when $subpool goes out of scope, so we borg all the
# info from it now..

    @nodes = map {
        Catalyst::Model::SVN::Item->new(
            {   repos       => $self->repository,
                name        => $_,
                path        => $path,
                svn         => $self,
                size        => $dirents->{$_}->size,
                kind        => $dirents->{$_}->kind,
                time        => $dirents->{$_}->time,
                author      => $dirents->{$_}->last_author,
                created_rev => $dirents->{$_}->created_rev,
            }
        );
    } sort keys %{$dirents};

    return wantarray ? @nodes : \@nodes;
}

# _ra_path( $path )
#
# Takes a path or URL, and returns a normalised from relative to the 
# configured repository path.

sub _ra_path { # FIXME - This is fugly..
    my ( $self, $path ) = @_;
    $path ||= '/';
    my $uri = URI->new($path);
    $path =~ s|//+|/|;
    my $ra_path;
    if ($uri->scheme) {
        # Was full URI
        $ra_path = file( $uri->path );
    }
    else {
        $ra_path = file( $self->repository->path, $path );
    }
    
    $ra_path = $ra_path->stringify;
    $ra_path =~ s|/$||; # Remove trailing / or svn can crash
    
    return $ra_path;
}

sub cat {
    my ( $self, $path, $revision ) = @_;
    return ( $self->_get_file( $path, $revision ) )[0];
}

sub propget {
    my ( $self, $path, $propname, $revision ) = @_;

    croak('No propname passed to propget method') unless defined $propname;
    
    my $props_hr = $self->properties_hr($path, $revision);
    return $props_hr->{$propname}
}

sub properties_hr {
    my ( $self, $path, $revision ) = @_;

    croak('No path passed to props_hr method') unless defined $path;
    
    return ( $self->_get_file( $path, $revision ) )[1];
}

=for comment _get_file( $path [, $revision] )

Calls the L<SVN::Ra> get_file method. Handles directories and files which 
have moved in older revisions

=cut

sub _get_file {
    my ( $self, $path, $revision ) = @_;
    my $repos_path = _ra_path( $self, $path );
    $revision = undef if ( defined $revision && $revision eq 'HEAD' );
    $revision ||= $SVN::Core::INVALID_REVNUM;
    my $requested_path = $repos_path;
    my $file           = IO::Scalar->new;
    my $subpool        = SVN::Pool::new_default_sub;
    my ( $revnum, $props );
    use Data::Dumper;
    eval {
        ( $revnum, $props )
            = $self->_ra->get_file( $repos_path, $revision, $file );

    };
    return ( $file, $props ) unless $@;

    # Handle dictionary case..
    if ( $@ =~ /Attempted to get checksum of a \*non\*-file node/ ) {
        return;
    }

    if ( $@ =~ /ile not found/ ) {
        $repos_path = $self->_resolve_copy( $repos_path, $revision );

        if ( $repos_path ne $requested_path ) {
            return $self->_get_file( $repos_path, $revision );
        }
    }

    die $@;
}

sub _resolve_copy {
    my ( $self, $path, $revision ) = @_;
    my $subpool = SVN::Pool::new_default_sub;

    my $copyfrom;
    $self->_ra->get_log(
        [$path],                       # const apr_array_header_t *paths,
        $self->_ra->get_latest_revnum, # svn_revnum_t start,
        $revision,                     # svn_revnum_t end,
        1,                             # svn_boolean_t discover_changed_paths,
        1,                             # svn_boolean_t strict_node_history,
        1,       # svn_boolean_t include_merged_revisions,
        sub {    # svn_log_entry_receiver_t receiver, void *receiver_baton
            return if $copyfrom;
            my $changes = shift;
            foreach my $change ( keys %$changes ) {
                my $obj    = $changes->{$change};
                my $action = $obj->action;
                $copyfrom = $obj->copyfrom_path;
                if ( $obj->action eq 'A' && $copyfrom ) {
                    $path =~ s/$change/$copyfrom/;
                    last;
                }
            }
        },
    );
    return $path;
}

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

Returns a URI object of the full path to the root of, or any directory in your Subversion
repository. This can be one of http://, svn://, or file:/// schemes. 

This value comes from the config key 'repository'.

=head2 revision

This is the default revision to use when no revision is specified. By default,
this will be C<HEAD>.

=head1 METHODS

=head2 cat($path [, $revision])

Returns the contents of the path specified. If C<path> is a copy, the logs are
transversed to find original. The request is then reissued for the original path
for the C<revision> specified.

=head2 ls($path [, $revision])

Returns a array of L<Catalyst::Model::SVN::Item> objects in list context, each
representing an entry in the specified repository path. In scalar context, it
returns an array reference.  If C<path> is a copy, the logs are
transversed to find the original. The request is then reissued for the original
path for the C<revision> specified.

=head2 propget($path, $propname [, $revision])

Returns a specific property for a path at a specified revision name.

Note: This method is inefficient, if you want to extract multiple properties 
of a single item then use the props_hr method.

=head2 properties_hr($path [, $revision])

Returns a reference to a hash with all the properties set on an object at a specific revision.

=head2 repository

Returns the repository specified in the configuration C<repository> option.

=head2 revision

Returns the latest revisions of the repository you are connected to.

=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Helper>, L<Catalyst::Model::SVN::Item>, L<SVN::Ra>

=head1 AUTHORS

    Christopher H. Laco
    CPAN ID: CLACO
    claco@chrislaco.com
    http://today.icantfocus.com/blog/
    
    Tomas Doran
    CPAN ID: BOBTFISH
    bobtfish@bobtfish.net
    
