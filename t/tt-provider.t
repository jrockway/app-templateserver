#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 3;

use ok 'App::TemplateServer::Provider::TT';
use ok 'App::TemplateServer::Context';
use Directory::Scratch;

my $tmp = Directory::Scratch->new;
$tmp->mkdir('foo');
$tmp->touch('include.tt', 'this got included');
$tmp->touch('plain.tt', 'this is plain TT');
$tmp->touch('try_include.tt', '>>"[% INCLUDE include.tt %]"<<');
$tmp->touch('subdir/foo.tt', 'hopefully subdirs also work');

my $ctx = App::TemplateServer::Context->new( data => { foo => 'bar' } );
my $provider = App::TemplateServer::Provider::TT->new(docroot => "$tmp");
is_deeply [sort qw\include.tt plain.tt try_include.tt subdir/foo.tt\],
          [sort $provider->list_templates],
  'got all expected templates via list_templates';
