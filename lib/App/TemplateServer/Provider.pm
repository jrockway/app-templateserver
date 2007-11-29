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
