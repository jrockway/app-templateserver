use inc::Module::Install;

name 'App::TemplateServer';
all_from 'lib/App/TemplateServer.pm';
license 'Perl';

requires 'HTTP::Daemon';
requires 'Template';

build_requires 'Test::More';
build_requires 'ok';

WriteAll();
