use strict;
use warnings;
use Module::Build;

# Build.PL

my $class = Module::Build->subclass(
  class => "Module::Build::Custom",
  code => <<'SUBCLASS' );

  # update version number of all packages in the distribution
  sub ACTION_version {
    my $self = shift;
    my $version = $self->dist_version();
    warn "Updating version to $version\n";
    $self->do_system($^X,qw(-pi~ -e ),q{ s/(\$VERSION\s*=\s*)['"].*['"](;\s*# version template)/$1'}.$version.q{'$2/},
					 grep { $_ ne 'lib/Treex/PML.pm' }
					 @{$self->rscan_dir('lib', qr/\.pm$/)});
  }
SUBCLASS

my $builder = $class->new(
    module_name         => 'Treex::PML',
    license             => 'perl',
    dist_abstract	=> 'Perl implementation of the Prague Marup Language (PML) and related data models.',
    dist_author         => q{Petr Pajas <pajas@matfyz.cz>},
    dist_version_from   => 'lib/Treex/PML.pm',

    share_dir => {
      module => {
	'Treex::PML::Backend::CSTS' => 'lib/Treex/PML/Backend/CSTS/share',
	'Treex::PML' => 'lib/Treex/PML/share',
      },
    },

    requires => {
      'perl' => '5.8.0',
      'File::Which' => 0,
      'IO::Zlib' => 0,
      'UNIVERSAL::DOES' => '0.004',
      'XML::CompactTree' => '0.03',
      'XML::LibXML' => '1.69',
      'XML::Writer' => '0.606',
      'File::ShareDir' => '1.00',
    },
    recommends => {
      'XML::LibXSLT' => '1.69',
      'XML::CompactTree::XS' => '0.02',
    },
    build_requires => {
        'Test::More' => 0,
        'Module::Build' => '0.36',
    },
    add_to_cleanup      => [ 'Treex-PML-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
