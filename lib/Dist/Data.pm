package Dist::Data;
# ABSTRACT: API to access the data of a Perl distribution file or directory

use Moo;
use Archive::Any;
use CPAN::Meta;
use File::Temp qw/ tempfile tempdir /;
use File::Find::Object;
use Module::Extract::Namespaces;
use DateTime::Format::Epoch::Unix;

has filename => (
	is => 'ro',
	predicate => 'has_filename',
);

has archive => (
	is => 'ro',
	lazy => 1,
	builder => '_build_archive',
);

sub _build_archive {
	my ( $self ) = @_;
	die __PACKAGE__.": need a filename" unless $self->has_filename;
	return Archive::Any->new($self->filename);
}

has distmeta => (
	is => 'ro',
	lazy => 1,
	builder => '_build_distmeta',
	handles => [qw(
		abstract
		description
		dynamic_config
		generated_by
		name
		release_status
		version
		authors
		keywords
		licenses
		meta_spec
		resources
		provides
		no_index
		prereqs
		optional_features
	)]
);

sub _build_distmeta {
	my ( $self ) = @_;
	if ($self->files->{'META.yml'}) {
		CPAN::Meta->load_file($self->files->{'META.yml'});
	} elsif ($self->files->{'META.json'}) {
		CPAN::Meta->load_file($self->files->{'META.json'});
	}
}

has dir => (
	is => 'ro',
	predicate => 'has_dir',
);

sub dir_has_dist {
	my ( $self ) = @_;
	my $dir = $self->dist_dir;
	return unless -d $dir;
	return -f "$dir/Makefile.PL";
}

has files => (
	is => 'ro',
	lazy => 1,
	builder => '_build_files',
);

sub _build_files {
	my ( $self ) = @_;
	$self->extract_distribution;
	my %files;
	for ($self->get_directory_tree($self->dist_dir)) {
		$files{join('/',@{$_->full_components})} = $_->path if $_->is_file;
	}
	return \%files;
}

has dist_dir => (
	is => 'ro',
	lazy => 1,
	builder => '_build_dist_dir',
);

sub _build_dist_dir {
	my ( $self ) = @_;
	return $self->has_dir ? $self->dir : tempdir;
}

sub extract_distribution {
	my ( $self ) = @_;
	return unless $self->has_filename;
	return if $self->dir_has_dist;
	my $ext_dir = tempdir;
	$self->archive->extract($ext_dir);
	for ($self->get_directory_tree($ext_dir)) {
		my @components = @{$_->full_components};
		shift @components;
		if ($_->is_dir) {
			mkdir $self->dist_dir.'/'.join('/',@components);
		} else {
			rename $_->path, $self->dist_dir.'/'.join('/',@components);
		}
	}
	return 1;
}

has packages => (
	is => 'ro',
	lazy => 1,
	builder => '_build_packages',
);

sub _build_packages {
	my ( $self ) = @_;
	my %packages;
	for (keys %{$self->files}) {
		my $key = $_;
		my @components = split('/',$key);
		if ($key =~ /\.pm$/) {
			my @namespaces = Module::Extract::Namespaces->from_file($self->files->{$key});
			for (@namespaces) {
				$packages{$_} = [] unless defined $packages{$_};
				push @{$packages{$_}}, $key;
			}
		} elsif ($key =~ /^lib\// && $key =~ /\.pod$/) {
			my $packagename = $key;
			$packagename =~ s/^lib\///g;
			$packagename =~ s/\.pod$//g;
			$packagename =~ s/\//::/g;
			$packages{$packagename} = [] unless defined $packages{$packagename};
			push @{$packages{$packagename}}, $key;
		}
	}
	return \%packages;
}

has scripts => (
	is => 'ro',
	lazy => 1,
	builder => '_build_scripts',
);

sub _build_scripts {
	my ( $self ) = @_;
	my %scripts;
	for (keys %{$self->files}) {
		next unless $_ =~ /^bin\// || $_ =~ /^script\//;
		my $key = $_;
		my @components = split('/',$key);
		shift @components;
		$scripts{join('/',@components)} = $key;
	}
	return \%scripts;
}

sub get_directory_tree {
	my ( $self, @dirs ) = @_;
	my $tree = File::Find::Object->new({}, @dirs);
	my @files;
	while (my $r = $tree->next_obj()) {
		push @files, $r;
	}
	return @files;
}

sub file {
	my ( $self, $file ) = @_;
	return $self->files->{$file};
}

sub modified {
    my ( $self ) = @_;
    my $mtime = stat($self->has_filename ? $self->filename : $self->dir )->mtime;
    return DateTime::Format::Epoch::Unix->parse_datetime($mtime);
}

sub BUILD {
	my ( $self ) = @_;
	$self->extract_distribution if $self->has_dir && $self->has_filename;
}

sub BUILDARGS {
	my ( $class, @args ) = @_;
	die __PACKAGE__.": please give filename on new" if !@args;
	my $arg; $arg = shift @args if @args % 2 == 1 && ref $args[0] ne 'HASH';
	if ($arg) {
		# should support URL also
		if (-f $arg) {
			return { filename => $arg, @args };
		} elsif (-d $arg) {
			return { dir => $arg, @args };
		}
	}
	return $class->SUPER::BUILDARGS(@args);
}

1;

=encoding utf8

=head1 SYNOPSIS

  use Dist::Data;

  my $dist = Dist::Data->new('My-Sample-Distribution-0.003.tar.gz');

  # Extract files into this directory, if it not already contains a distribution
  my $otherdist = Dist::Data->new({
    dir => '/storage/extracted-dists/My-Sample-Distribution-0.003',
    filename => 'My-Sample-Distribution-0.003.tar.gz',
  });

  my $otherdist_via_dir = Dist::Data->new({
    dir => '/storage/extracted-dists/My-Sample-Distribution-0.003',
  });

  my %files = %{$dist->files};

  my $filename_of_distini = $dist->file('dist.ini');

  my $cpan_meta = $dist->distmeta; # gives back CPAN::Meta

  my $version = $dist->version; # handled by CPAN::Meta object
  my $name = $dist->name;       # also

  my @authors = $dist->authors;

  my %packages = %{$dist->packages};
  my %scripts = %{$dist->scripts};
  
=head1 DESCRIPTION

This distribution is used to get all information from a CPAN distribution or an extracted CPAN distribution. It tries to combine the power of other modules. Longtime it should be possible to define alternative behaviour (to be more like search.cpan.org or be like metacpan.org or whatever other system that parses CPAN Distributions).

=head1 SUPPORT

IRC

  Join #duckduckgo on irc.freenode.net. Highlight Getty for fast reaction :).

Repository

  http://github.com/Getty/p5-dist-data
  Pull request and additional contributors are welcome
 
Issue Tracker

  http://github.com/Getty/p5-dist-data/issues


