package App::TemplateServer;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class qw(Dir);

use HTTP::Daemon;
use HTTP::Headers;
use HTTP::Request;
use HTTP::Response;

use App::TemplateServer::Types;
use App::TemplateServer::Provider::TT;
use App::TemplateServer::Page::Index;
use App::TemplateServer::Context;

our $VERSION = '0.01';
our $AUTHORITY = 'cpan:JROCKWAY';

with 'MooseX::Getopt';

has 'port' => (
    is       => 'ro',
    isa      => 'Port',
    default  => '4000',
);

has 'docroot' => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    default  => sub { $ENV{PWD} },
    lazy     => 1,
);

coerce 'ClassName'
  => as 'Str',
  => via { Class::MOP::load_class($_) and $_ };

has 'provider_class' => (
    metaclass  => 'MooseX::Getopt::Meta::Attribute',
    cmd_arg    => 'provider',
    is         => 'ro',
    isa        => 'ClassName',
    default    => 'App::TemplateServer::Provider::TT',
    coerce     => 1,
);

has 'provider' => (
    metaclass => 'NoGetopt',
    is        => 'ro',
    isa       => 'Provider',
    lazy      => 1,
    default   => sub {
        my $self = shift; 
        $self->provider_class->new(docroot => $self->docroot);
    },
);

has '_daemon' => (
    is       => 'ro',
    isa      => 'HTTP::Daemon',
    lazy     => 1,
    default  => sub { 
        return HTTP::Daemon->new(ReuseAddr => 1, LocalPort => shift->port);
    },
);

sub run {
    my $self = shift;
    print "Server started at: ". $self->_daemon->url. "\n";
    $self->_main_loop;
}

sub _main_loop {
    my ($self) = @_;
  app:
    while(my $c = $self->_daemon->accept){
      req:
        while (my $req = $c->get_request){
            my $res = $self->_req_handler($req);
            $c->send_response($res);
        }
    }
}

sub _req_handler {
    my ($self, $req) = @_;
    my $res = eval {
        if($req->uri =~ m{^/(?:index(?:[.]html?)?)?$}){
            $self->_render_index($req);
        }
        else {
            $self->_render_template($req);
        }
    };
    if($@ || !$res){
        my $h = HTTP::Headers->new;
        $res = HTTP::Response->new(500, 'Internal Server Error', $h, $@);
    }
    
    return $res;
}

sub _success {
    my ($content) = @_;
    my $headers = HTTP::Headers->new;
    return HTTP::Response->new(200, 'OK', $headers, $content);
}

sub _mk_context {
    my ($self, $req) = @_;
    return App::TemplateServer::Context->new(
        data    => {},
        request => $req,
        server  => $self->_daemon,
    );
}

sub _render_template {
    my ($self, $req) = @_;
    my $context = $self->_mk_context($req);
    my $template = $req->uri;
    $template =~ s{^/}{};
    my $content = $self->provider->render_template($template, $context);
    return _success($content);
}

sub _render_index {
    my ($self, $req) = @_;

    my $index = App::TemplateServer::Page::Index->new(
        provider => $self->provider,
    );
    my $context = $self->_mk_context($req);
    my $content = $index->render($context);
    
    return _success($content);
}

1;
__END__

=head1 NAME

App::TemplateServer - application to serve processed templates

=head1 SYNOPSIS

=head1 AUTHOR

Jonathan Rockway C<< <jrockway@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2007 Jonathan Rockway.  You may redistribute this module
under the same terms as Perl itself.


