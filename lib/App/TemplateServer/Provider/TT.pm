package App::TemplateServer::Provider::TT;
use Moose;
use File::Find;
use File::Spec;
use Template;

with 'App::TemplateServer::Provider';

has 'engine' => (
    is      => 'ro',
    isa     => 'Template',
    default => sub { Template->new({ INCLUDE_PATH => shift->docroot }) },
    lazy    => 1,
);

sub list_templates {
    my $self = shift;
    my $docroot = $self->docroot;
    
    my @files;
    find(sub { push @files, File::Spec->abs2rel($File::Find::name, $docroot) },
         $docroot);
    return @files;
}

sub render_template {
    my ($self, $template, $context) = @_;
    my $out;
    $self->engine->process($template, {}, \$out)
      or die "Failed to render: ". $self->engine->error;
    return $out;
}

1;
