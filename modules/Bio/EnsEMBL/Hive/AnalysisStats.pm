#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME
  Bio::EnsEMBL::Hive::AnalysisStats

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT
  Contact Jessica Severin on EnsEMBL::Hive implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX
  The rest of the documentation details each of the object methods.
  Internal methods are usually preceded with a _
=cut

package Bio::EnsEMBL::Hive::AnalysisStats;

use strict;

use Bio::EnsEMBL::Root;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::Worker;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Root);


sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}

sub update {
  my $self = shift;
  return unless($self->adaptor);
  $self->adaptor->update($self);
}

sub analysis_id {
  my $self = shift;
  $self->{'_analysis_id'} = shift if(@_);
  return $self->{'_analysis_id'};
}

sub status {
  my ($self, $value ) = @_;

  if(defined $value) {
    $self->{'_status'} = $value;
  }
  return $self->{'_status'};
}

sub batch_size {
  my $self = shift;
  $self->{'_batch_size'} = shift if(@_);
  return $self->{'_batch_size'};
}

sub hive_capacity {
  my $self = shift;
  $self->{'_hive_capacity'} = shift if(@_);
  return $self->{'_hive_capacity'};
}

sub total_job_count {
  my $self = shift;
  $self->{'_total_job_count'} = shift if(@_);
  return $self->{'_total_job_count'};
}

sub unclaimed_job_count {
  my $self = shift;
  $self->{'_unclaimed_job_count'} = shift if(@_);
  return $self->{'_unclaimed_job_count'};
}

sub done_job_count {
  my $self = shift;
  $self->{'_done_job_count'} = shift if(@_);
  return $self->{'_done_job_count'};
}

sub num_required_workers {
  my $self = shift;
  $self->{'_num_required_workers'} = shift if(@_);
  return $self->{'_num_required_workers'};
}

sub seconds_since_last_update {
  my( $self, $value ) = @_;
  $self->{'_last_update'} = time() - $value if(defined($value));
  return time() - $self->{'_last_update'};
}

sub determine_status {
  my $self = shift;
  
  if($self->status ne 'BLOCKED') {
    if($self->done_job_count>0 and
       $self->total_job_count == $self->done_job_count) {
      $self->status('DONE');
    }
    if($self->total_job_count == $self->unclaimed_job_count) {
      $self->status('READY');
    }
    if($self->unclaimed_job_count>0 and
       $self->total_job_count > $self->unclaimed_job_count) {
      $self->status('WORKING');
    }
  }
  return $self;
}
  
sub print_stats {
  my $self = shift;

  printf("ANALYSIS_STATS (%d) %s batch=%d capacity=%d jobs(%d,%d,%d) clutchSize=%d (age %d secs)\n",
        $self->analysis_id,
        $self->status,
        $self->batch_size,$self->hive_capacity(),
        $self->total_job_count,$self->unclaimed_job_count,$self->done_job_count,
        $self->num_required_workers,
        $self->seconds_since_last_update);
}

1;
