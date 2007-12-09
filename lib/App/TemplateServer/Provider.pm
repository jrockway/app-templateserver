package App::TemplateServer::Provider;
use Moose::Role;
use MooseX::Types::Path::Class qw(Dir);

has 'docroot' => (
    is       => 'ro',
    isa      => Dir,
    required => 1,
    coerce   => 1,
);

requires 'list_templates';
requires 'render_template';

1;

__END__

=head1 NAME

App::TemplateServer::Provider - role that a Provider should do

=head1 DESCRIPTION

Template systems are interfaced with App::TemplateServer with this
role.  The template server will call the methods required by this role
to provider its functionality.

=head1 ATTRIBUTES

This role provides the following attributes:

=head2 docroot

This is the directory where your templates that you are "providing"
live.  It is required.

=head1 REQUIRED METHODS

You need to implement these:

=head2 list_templates

Returns a list of strings representing template names.

=head2 render_template($template, $context)

Return the rendered text of the template named by C<$template>.  If
C<$template> can't be rendered, throw an exception.  C<$context> is
the L<App::TemplateServer::Context|App::TemplateServer::Context>
object for the request.

=head1 SEE ALSO

L<App::TemplateServer|App::TemplateServer>
