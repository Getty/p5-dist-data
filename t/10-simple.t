#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

use Dist::Data;

BEGIN {

	my $dist = Dist::Data->new("$Bin/data/My-Sample-Distribution-0.003.tar.gz");

	isa_ok($dist,'Dist::Data');

	my @keys = sort keys %{$dist->files};
	
	is_deeply(\@keys,[qw(
		Changes
		LICENSE
		MANIFEST
		META.json
		META.yml
		Makefile.PL
		README
		bin/my_sample_distribution
		dist.ini
		lib/My/Sample/Distribution.pm
		lib/My/Sample/Documentation.pod
		t/release-pod-syntax.t
	)],'Checking files');

	like($dist->file('dist.ini'),qr/\/dist.ini$/,'Checking if file function gives back valid filename');
	ok(-f $dist->file('dist.ini'),'Checking if file exist');
	is((stat($dist->file('dist.ini')))[7],214,'Checking filesize');
	
	isa_ok($dist->distmeta,'CPAN::Meta');
	
	is($dist->version,'0.003','Checking version from meta');
	is($dist->name,'My-Sample-Distribution','Checking name from meta');
	is($dist->generated_by,'Dist::Zilla version 4.300003, CPAN::Meta::Converter version 2.113640','Checking generated_by from meta');
	
	is_deeply([$dist->authors],['Torsten Raudssus <torsten@raudssus.de>','Another Author <someone@somewhere>'],'Checking authors from meta');

	is_deeply($dist->meta_spec,{
		version => 2,
		url => 'http://search.cpan.org/perldoc?CPAN::Meta::Spec',
	},'Checking meta specification from meta');
	
	is_deeply($dist->packages, {
		'My::Sample::Distribution' => ['lib/My/Sample/Distribution.pm'],
		'My::Sample::Documentation' => ['lib/My/Sample/Documentation.pod'],
	},'Checking package definitions');

	is_deeply($dist->scripts, {
		'my_sample_distribution' => 'bin/my_sample_distribution',
	},'Checking scripts definitions');

}

done_testing;
