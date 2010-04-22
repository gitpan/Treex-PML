package Treex::PML::Backend::PML;

use Treex::PML;
use Treex::PML::IO qw(close_backend);
use strict;
use warnings;

use vars qw($VERSION);
BEGIN {
  $VERSION='2.02'; # version template
}

use Treex::PML::Instance qw( :all :diagnostics $DEBUG );

use constant EMPTY => q{};

use Carp;

use vars qw($config $config_file $allow_no_trees $config_inc_file $TRANSFORM @EXPORT_OK);

use Exporter qw(import);

BEGIN {
  $TRANSFORM=0;
  @EXPORT_OK = qw(open_backend close_backend test read write);
  $config = undef;
  $config_file = 'pmlbackend_conf.xml';
  $config_inc_file = 'pmlbackend_conf.inc';
  $allow_no_trees = 0;
}

sub _caller_dir {
  return File::Spec->catpath(
    (File::Spec->splitpath( (caller)[1] ))[0,1],''
  );
}

sub configure {
  return 0 unless eval {
    require XML::LibXSLT;
  };
  undef $config;
  my @resource_path = Treex::PML::ResourcePaths();
  Treex::PML::AddResourcePath(_caller_dir());
  my $file = Treex::PML::FindInResources($config_file,{strict=>1});
  if ($file and -f $file) {
    _debug("config file: $file");
    $config = Treex::PML::Instance->load({filename => $file});
  }
  return unless $config;
  my @config_files = Treex::PML::FindInResources($config_inc_file,{all=>1});
  my $T = $config->get_root->{transform_map} ||= Treex::PML::Factory->createSeq();
  for my $file (reverse @config_files) {
    _debug("config include file: $file");
    eval {
      my $c = Treex::PML::Instance->load({filename => $file});
      # merge
      my $t = $c->get_root->{transform_map};
      if ($t) {
	for my $transform (reverse $t->elements) {
	  my $copy = Treex::PML::CloneValue($transform);
	  $T->unshift_element_obj($copy);
	  if (ref($copy->value) and $copy->value->{id}) {
	    $config->hash_id($copy->value->{id}, $copy->value, 1);
	  }
	}
      }
    };
    warn $@ if $@;
  }
  Treex::PML::SetResourcePaths(@resource_path);
  return $config;
}


###################

sub open_backend {
  my ($filename, $mode, $encoding)=@_;
  my $fh = Treex::PML::IO::open_backend($filename,$mode) # discard encoding
    || die "Cannot open $filename for ".($mode eq 'w' ? 'writing' : 'reading').": $!";
  return $fh;
}

sub read ($$) {
  my ($input, $fsfile)=@_;
  return unless ref($fsfile);

  my $ctxt = Treex::PML::Instance->load({fh => $input, filename => $fsfile->filename, config => $config });
  $ctxt->convert_to_fsfile( $fsfile );
  my $status = $ctxt->get_status;
  if ($status and 
      !($allow_no_trees or defined($ctxt->get_trees))) {
    _die("No trees found in the Treex::PML::Instance!");
  }
  return $status
}


sub write {
  my ($fh,$fsfile)=@_;
  my $ctxt = Treex::PML::Instance->convert_from_fsfile( $fsfile );
  $ctxt->save({ fh => $fh, config => $config });
}


sub test {
  my ($f,$encoding)=@_;
  if (ref($f)) {
    local $_;
    if ($TRANSFORM and $config) {
      1 while ($_=$f->getline() and !/\S/);
      # see <, assume XML
      return 1 if (defined and /^\s*</);
    } else {
      # only accept PML instances
      # xmlns:...="..pml-namespace.." must occur in the first tag (on one line)
      my ($in_first_tag,$in_pi,$in_comment);
      while ($_=$f->getline()) {
	next if !/\S/;  # whitespace
	if ($in_first_tag) {
	  last if />/;
	  return 1 if m{\bxmlns(?::[[:alnum:]]+)?=([\'\"])http://ufal.mff.cuni.cz/pdt/pml/\1};
	  next;
	} elsif ($in_pi) {
	  next unless s/^.*?\?>//;
	  $in_pi=0;
	} elsif ($in_comment) {
	  next unless s/^.*?\-->//;
	  $in_comment=0;
	}
	s/^(?:\s*<\?.*?\?>|\s*<!--.*?-->)*\s*//;
	if (/<\?/) {
	  $in_pi=1;
	} elsif (/<!--/) {
	  $in_comment=1;
	} elsif (/^</) {
	  last if />/;
	  $in_first_tag=1;
	  return 1 if m{^[^>]*xmlns(?::[[:alnum:]]+)?=([\'\"])http://ufal.mff.cuni.cz/pdt/pml/\1};
	} elsif (length) {
	  return 0; # nothing else allowed before the first tag
	}
      }
      return 0 if !$in_first_tag && !(defined($_) and s/^\s*<//);
      return 1 if defined($_) and m{^[^>]*xmlns(?::[[:alnum:]]+)?=([\'\"])http://ufal.mff.cuni.cz/pdt/pml/\1};
      return 0;
    }
  } else {
    my $fh = Treex::PML::IO::open_backend($f,"r");
    my $test = $fh && test($fh,$encoding);
    Treex::PML::IO::close_backend($fh);
    return $test;
  }
}


######################################################


################### 
# INIT
###################
package Treex::PML::Backend::PML;
eval {
  configure();
};
Carp::cluck( $@ ) if $@;

1;

=pod

=head1 NAME

Treex::PML::Backend::PML - I/O backend for PML documents

=head1 SYNOPSIS

use Treex::PML;
Treex::PML::AddBackends(qw(PML))

my $document = Treex::PML::Factory->createDocumentFromFile('input.pml');
...
$document->save();

=head1 DESCRIPTION

This module implements a Treex::PML input/output backend which accepts
reads/writes PML files. See L<Treex::PML::Instance> for details.

NOTE: L<Treex::PML> enables this backend by default.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2010 by Petr Pajas

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
