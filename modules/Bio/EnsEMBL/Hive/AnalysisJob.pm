=pod 

=head1 NAME

    Bio::EnsEMBL::Hive::AnalysisJob

=head1 DESCRIPTION

    An AnalysisJob is the link between the input_id control data, the analysis and
    the rule system.  It also tracks the state of the job as it is processed

=head1 LICENSE

    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016] EMBL-European Bioinformatics Institute

    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

=head1 CONTACT

    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates

=head1 APPENDIX

    The rest of the documentation details each of the object methods.
    Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Hive::AnalysisJob;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Bio::EnsEMBL::Hive::Utils ('stringify', 'destringify');
use Bio::EnsEMBL::Hive::DBSQL::DataflowRuleAdaptor;

use base (  'Bio::EnsEMBL::Hive::Cacheable',# mainly to inherit hive_pipeline() method
            'Bio::EnsEMBL::Hive::Storable', # inherit dbID(), adaptor() and new() methods
            'Bio::EnsEMBL::Hive::Params',   # inherit param management functionality
         );


=head1 AUTOLOADED

    prev_job_id / prev_job

    analysis_id / analysis

=cut


sub input_id {          # keep the actual parameters in _own_params_hashref, only stringify on return
    my $self = shift;
    if(@_) {
        my $input_id = shift @_;
        $self->{'_own_params_hashref'} = ref($input_id) ? $input_id : destringify($input_id);
    }

    return stringify( $self->own_params_hashref );
}

sub own_params_hashref {
    my $self = shift;

    $self->{'_own_params_hashref'} = shift if(@_);

    if(!defined( $self->{'_own_params_hashref'} ) and $self->adaptor and $self->dbID) {     # lazy loading
        $self->{'_own_params_hashref'} = $self->adaptor->db->get_ParametersAdaptor->fetch_job_parameters_hashref( $self->dbID );
    }
    return $self->{'_own_params_hashref'};
}

sub param_checksum {
    my $self = shift;

    $self->{'_param_checksum'} = shift if(@_);

    unless(defined($self->{'_param_checksum'})) {
        my $own_params_hashref = $self->own_params_hashref;     # this should trigger lazy-loading if parameters have not been seen yet
        my $group_concat = join(',', map { md5_hex( $_.'=>'.stringify($own_params_hashref->{$_} ) ) } sort keys %$own_params_hashref );
        $self->{'_param_checksum'} = md5_hex( $group_concat );
    }

    return $self->{'_param_checksum'};
}

sub param_id_stack {
    my $self = shift;
    $self->{'_param_id_stack'} = shift if(@_);
    $self->{'_param_id_stack'} = '' unless(defined($self->{'_param_id_stack'}));
    return $self->{'_param_id_stack'};
}

sub role_id {
    my $self = shift;
    $self->{'_role_id'} = shift if(@_);
    return $self->{'_role_id'};
}

sub status {
    my $self = shift;
    $self->{'_status'} = shift if(@_);
    $self->{'_status'} = ( ($self->semaphore_count>0) ? 'SEMAPHORED' : 'READY' ) unless(defined($self->{'_status'}));
    return $self->{'_status'};
}

sub retry_count {
    my $self = shift;
    $self->{'_retry_count'} = shift if(@_);
    $self->{'_retry_count'} = 0 unless(defined($self->{'_retry_count'}));
    return $self->{'_retry_count'};
}

sub when_completed {
    my $self = shift;
    $self->{'_when_completed'} = shift if(@_);
    return $self->{'_when_completed'};
}

sub runtime_msec {
    my $self = shift;
    $self->{'_runtime_msec'} = shift if(@_);
    $self->{'_runtime_msec'} = 0 unless(defined($self->{'_runtime_msec'}));
    return $self->{'_runtime_msec'};
}

sub query_count {
    my $self = shift;
    $self->{'_query_count'} = shift if(@_);
    $self->{'_query_count'} = 0 unless(defined($self->{'_query_count'}));
    return $self->{'_query_count'};
}

sub semaphore_count {
    my $self = shift;
    $self->{'_semaphore_count'} = shift if(@_);
    $self->{'_semaphore_count'} = 0 unless(defined($self->{'_semaphore_count'}));
    return $self->{'_semaphore_count'};
}

sub semaphored_job_id {
    my $self = shift;
    $self->{'_semaphored_job_id'} = shift if(@_);
    return $self->{'_semaphored_job_id'};
}

sub set_and_update_status {
    my ($self, $status ) = @_;

    $self->status($status);

    if(my $adaptor = $self->adaptor) {
        $adaptor->check_in_job($self);
    }
}

sub stdout_file {
  my $self = shift;
  $self->{'_stdout_file'} = shift if(@_);
  return $self->{'_stdout_file'};
}

sub stderr_file {
  my $self = shift;
  $self->{'_stderr_file'} = shift if(@_);
  return $self->{'_stderr_file'};
}


=head2 autoflow

    Title   :  autoflow
    Function:  Gets/sets flag for whether the job should
               be automatically dataflowed on branch 1 when the job completes.
               If the subclass manually sends a job along branch 1 with dataflow_output_id,
               the autoflow will turn itself off.
    Returns :  boolean (1=default|0)

=cut

sub autoflow {
  my $self = shift;

  $self->{'_autoflow'} = shift if(@_);
  $self->{'_autoflow'} = 1 unless(defined($self->{'_autoflow'}));  

  return $self->{'_autoflow'};
}


##-----------------[indicators to the Worker]--------------------------------


sub lethal_for_worker {     # Job should set this to 1 prior to dying (or before running code that might cause death - such as RunnableDB's compilation)
                            # if it believes that the state of things will not allow the Worker to continue normally.
                            # The Worker will check the flag and commit suicide if it is set to true.
    my $self = shift;
    $self->{'_lethal_for_worker'} = shift if(@_);
    return $self->{'_lethal_for_worker'};
}

sub transient_error {       # Job should set this to 1 prior to dying (or before running code that might cause death)
                            # if it believes that it makes sense to retry the same job without any changes.
                            # It may also set it to 0 prior to dying (or before running code that might cause death)
                            # if it believes that there is no point in re-trying (say, if the parameters are wrong).
                            # The Worker will check the flag and make necessary adjustments to the database state.
    my $self = shift;
    $self->{'_transient_error'} = shift if(@_);
    return $self->{'_transient_error'};
}

sub incomplete {            # Job should set this to 0 prior to throwing if the job is done,
                            # but it wants the thrown message to be recorded with is_error=0.
    my $self = shift;
    $self->{'_incomplete'} = shift if(@_);
    return $self->{'_incomplete'};
}


sub died_somewhere {
    my $self = shift;

    $self->{'_died_somewhere'} ||= shift if(@_);    # NB: the '||=' only applies in this case - do not copy around!
    return $self->{'_died_somewhere'} ||=0;
}

##-----------------[/indicators to the Worker]-------------------------------


sub load_parameters {
    my ($self, $runnable_object) = @_;

    my @params_precedence = ();

    push @params_precedence, $runnable_object->param_defaults if($runnable_object);

    push @params_precedence, $self->hive_pipeline->params_as_hash;

    push @params_precedence, $self->analysis->parameters if($self->analysis);

    if(my $job_adaptor = $self->adaptor) {
        my $job_id          = $self->dbID;
        my $accu_adaptor    = $job_adaptor->db->get_AccumulatorAdaptor;
        my $param_adaptor   = $job_adaptor->db->get_ParametersAdaptor;

        unless($self->retry_count) {
            my $own_params_hashref  = $self->own_params_hashref;
            my $accu_hashref        = $accu_adaptor->fetch_structures_for_job_ids( $job_id )->{ $job_id };
            if(keys %$accu_hashref) {
                foreach my $param_name (keys %$accu_hashref) {
                    $own_params_hashref->{$param_name} = $accu_hashref->{$param_name};
                }
                $self->param_checksum(undef);   # trigger re-computation

                my $return_code = $self->adaptor->update( $self )
                        # using $return_code in boolean context allows to skip the value '0E0' ('no rows affected') that Perl treats as zero but regards as true:
                    or throw("Could not update job's param_checksum : likely collision, please investigate");
                if($return_code == 1) {     # <--- for the same reason we have to be explicitly numeric here (number of updated rows)

                        # if param_checksum got updated, we need to upsert all the accumulated parameters:
                    foreach my $param_name (keys %$accu_hashref) {
                        my $param_entry = { 'job_id' => $job_id, 'param_name' => $param_name, 'param_value' => $own_params_hashref->{$param_name} };

                        $param_adaptor->store_or_update_one( $param_entry, ['job_id', 'param_name', 'param_value'] );
                    }
                }
            }
        }

        if($self->param_id_stack) {
            my $job_params_hashes   = $param_adaptor->fetch_param_hashrefs_for_job_ids( $self->param_id_stack );
            push @params_precedence, @{$job_params_hashes}{ sort { $a <=> $b } keys %$job_params_hashes }; # take a slice. Mmm...
        }
    }

    push @params_precedence, $self->own_params_hashref;

    $self->param_init( @params_precedence );
}


sub fan_cache {     # a self-initializing getter (no setting)
                    # Returns a hash-of-lists { 2 => [list of jobs waiting to be funneled into 2], 3 => [list of jobs waiting to be funneled into 3], etc}
    my $self = shift;

    return $self->{'_fan_cache'} ||= {};
}

=head2 dataflow_output_id

    Title        :  dataflow_output_id
    Arg[1](req)  :  <string> $output_id 
    Arg[2](opt)  :  <int> $branch_name_or_code (optional, defaults to 1)
    Usage        :  $self->dataflow_output_id($output_id, $branch_name_or_code);
    Function:  
      If a RunnableDB(Process) needs to create jobs, this allows it to have jobs 
      created and flowed through the dataflow rules of the workflow graph.
      This 'output_id' becomes the 'input_id' of the newly created job at
      the ends of the dataflow pipes.  The optional 'branch_name_or_code' determines
      which dataflow pipe(s) to flow the job through.      

=cut

sub dataflow_output_id {
    my ($self, $output_ids, $branch_name_or_code) = @_;

    my $input_id                = $self->input_id();
    my $hive_use_param_stack    = $self->hive_pipeline->hive_use_param_stack;

    $output_ids  ||= [ $hive_use_param_stack ? {} : $input_id ];            # by default replicate the parameters of the parent in the child
    $output_ids    = [ $output_ids ] unless(ref($output_ids) eq 'ARRAY');   # force previously used single values into an arrayref

        # map branch names to numbers:
    my $branch_code = Bio::EnsEMBL::Hive::DBSQL::DataflowRuleAdaptor::branch_name_2_code($branch_name_or_code);

        # if branch_code is set to 1 (explicitly or implicitly), turn off automatic dataflow:
    $self->autoflow(0) if($branch_code == 1);

    my @output_job_ids = ();

        # fan rules come sorted before funnel rules for the same branch_code:
    foreach my $df_rule ( @{ $self->analysis->dataflow_rules_by_branch->{$branch_code} || [] } ) {

        my $targets_grouped_by_condition    = $df_rule->get_my_targets_grouped_by_condition;    # the pairs are deliberately ordered to put the DEFAULT branch last
        my @conditions                      = map { $_->[0] } @$targets_grouped_by_condition;

        my $total_output_ids_for_the_rule = 0;

        foreach my $output_id (@$output_ids) {  # filter the output_ids and place them into the [2] part of $targets_grouped_by_condition
            my $condition_match_count = 0;
            foreach my $condition_idx (0..@conditions-1) {
                my $unsubstituted_condition = $conditions[$condition_idx];

                if(defined($unsubstituted_condition)) {
                    if(my $substituted_condition = $self->param_substitute('#expr('.$unsubstituted_condition.')expr#', $output_id)) {
                        $condition_match_count++;
                    } else {
                        next;   # non-DEFAULT condition branch failed
                    }
                } elsif($condition_match_count) {
                    next;   # DEFAULT condition branch failed, because one of the conditions fired
                } else {
                    # DEFAULT condition branch succeeded => follow to the push
                }

                push @{$targets_grouped_by_condition->[$condition_idx][2]}, $output_id;
                $total_output_ids_for_the_rule += scalar( @{ $targets_grouped_by_condition->[$condition_idx][1] } );
            }
        }

        my $fan_cache_for_this_rule = exists($self->fan_cache->{"$df_rule"}) && $self->fan_cache->{"$df_rule"};
        if($fan_cache_for_this_rule && @$fan_cache_for_this_rule && $total_output_ids_for_the_rule!=1) {
            die "The total number of funnel output_ids (considering ".scalar(@conditions)." conditions) was $total_output_ids_for_the_rule, but expected to be 1. Please investigate";
        }

        foreach my $triple (@$targets_grouped_by_condition) {
            my ($unsubstituted_condition, $df_targets, $filtered_output_ids) = @$triple;

            if($filtered_output_ids && @$filtered_output_ids) {

                foreach my $df_target (@$df_targets) {

                        # parameter substitution into input_id_template is rule-specific
                    my $output_ids_for_this_rule;
                    if(my $template_string = $df_target->input_id_template()) {
                        my $template_hash = destringify($template_string);
                        $output_ids_for_this_rule = [ map { $self->param_substitute($template_hash, $_) } @$filtered_output_ids ];
                    } else {
                        $output_ids_for_this_rule = $filtered_output_ids;
                    }

                    my ($stored_listref) = $df_target->to_analysis->dataflow( $output_ids_for_this_rule, $self,
                                                                                $hive_use_param_stack || $df_target->extend_param_stack, $df_rule );

                    push @output_job_ids, @$stored_listref;

                } # /foreach my $df_target
            } # /if(filtered_output_ids are workable)
        } # /foreach my $unsubstituted_condition
    } # /foreach my $df_rule

    return \@output_job_ids;
}


sub toString {
    my $self = shift @_;

    my $analysis_label = $self->analysis
        ? ( $self->analysis->logic_name.'('.$self->analysis_id.')' )
        : '(NULL)';

    return 'Job dbID='.($self->dbID || '(NULL)')." analysis=$analysis_label, input_id='".$self->input_id."', status=".$self->status.", retry_count=".$self->retry_count;
}


1;

