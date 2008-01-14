package App::TemplateServer;
use feature ':5.10';

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class qw(File Dir);

use HTTP::Daemon;
use HTTP::Headers;
use HTTP::Request;
use HTTP::Response;

use App::TemplateServer::Types;
use App::TemplateServer::Provider::TT;
use App::TemplateServer::Page::Index;
use App::TemplateServer::Context;

use Package::FromData;
use Method::Signatures;
use YAML::Syck qw(LoadFile);

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

has 'datafile' => ( # mocked data for the templates to use
    isa      => File,
    is       => 'ro',
    coerce   => 1,
    required => 0,
);

has '_raw_data' => ( 
    isa     => 'HashRef',
    is      => 'ro',
    default => sub { eval { LoadFile($_[0]->datafile) } || {} },
    lazy    => 1,
);

has '_data' => (
    isa     => 'HashRef',
    is      => 'ro',
    default => sub {
        my $self = shift;
        my $raw_data    = $self->_raw_data;
        my $package_def = delete $raw_data->{packages};
        create_package_from_data($package_def) if $package_def;

        my $to_instantiate = delete $raw_data->{instantiate};
        foreach my $var (keys %{$to_instantiate||{}}){
            my $class = $to_instantiate->{$var};
            given(ref $class){
                when('HASH'){
                    my ($package, $method) = %$class;
                    $raw_data->{$var} = $package->method;
                }
                default {
                    $raw_data->{$var} = $class->new;
                }
            }
        }

        return $raw_data;
    },
    lazy => 1,
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

method run {
    print "Server started at: ". $self->_daemon->url. "\n";
    $self->_main_loop;
};

method _main_loop {
    local $SIG{CHLD} = 'IGNORE';
  app:
    while(my $c = $self->_daemon->accept){
        if(!fork){
          req:
            while (my $req = $c->get_request){
                my $res = $self->_req_handler($req);
                $c->send_response($res);
            }
            $c->close;
            exit; # exit child
        }
    }
};

method _req_handler($req) {
    my $res = eval {
        given($req->uri){
            when(m{^/(?:index(?:[.]html?)?)?$}){
                return $self->_render_index($req);
            }
            when(m{^/favicon.ico$}){
                return $self->_render_favicon($req);
            }
            default {
                return $self->_render_template($req);
            }
        }
    };
    if($@ || !$res){
        my $h = HTTP::Headers->new;
        $res = HTTP::Response->new(500, 'Internal Server Error', $h, $@);
    }
    
    return $res;
};

sub _success {
    my $content = shift;
    my $headers = HTTP::Headers->new;

    # set up utf8
    $headers->header('content-type' => 'text/html; charset=utf8');
    utf8::upgrade($content); # kill latin1
    utf8::encode($content);

    return HTTP::Response->new(200, 'OK', $headers, $content);
}

method _mk_context($req) {
    return App::TemplateServer::Context->new(
        data    => $self->_data,
        request => $req,
        server  => $self->_daemon,
    );
};

method _render_template($req) {
    my $context = $self->_mk_context($req);
    my $template = $req->uri;
    $template =~ s{^/}{};
    my $content = $self->provider->render_template($template, $context);
    return _success($content);
};

method _render_index($req) {

    my $index = App::TemplateServer::Page::Index->new(
        provider => $self->provider,
    );
    my $context = $self->_mk_context($req);
    my $content = $index->render($context);
    return _success($content);
};

method _render_favicon($req){
    return HTTP::Response->new(404, 'Not found');
};

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


