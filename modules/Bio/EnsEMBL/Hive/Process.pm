
=pod 

=head1 NAME

  Bio::EnsEMBL::Hive::Process

=head1 SYNOPSIS

  Abstract superclass.  Each Process makes up the individual building blocks 
  of the system.  Instances of these processes are created in a hive workflow 
  graph of Analysis entries that are linked together with dataflow and 
  AnalysisCtrl rules.
  
  Instances of these Processes are created by the system as work is done.
  The newly created Process will have preset $self->queen, $self->dbc, 
  $self->input_id, $self->analysis and several other variables. 
  From this input and configuration data, each Process can then proceed to 
  do something.  The flow of execution within a Process is:
    fetch_input();
    run();
    write_output();
    DESTROY
  The developer can implement their own versions of fetch_input, run, 
  write_output, and DESTROY to do what they need.  
  
  The entire system is based around the concept of a workflow graph which
  can split and loop back on itself.  This is accomplished by dataflow
  rules (or pipes) that connect one Process (or analysis) to others.
  Where a unix commandline program can send output on STDOUT STDERR pipes, 
  a hive Process has access to unlimited pipes referenced by numerical 
  branch_codes. This is accomplished within the Process via 
  $self->dataflow_output_id(...);  
  
  The design philosophy is that each Process does it's work and creates output, 
  but it doesn't worry about where the input came from, or where it's output 
  goes. If the system has dataflow pipes connected, then the output jobs 
  have purpose, if not the output work is thrown away.  The workflow graph 
  'controls' the behaviour of the system, not the processes.  The processes just 
  need to do their job.  The design of the workflow graph is based on the knowledge 
  of what each Process does so that the graph can be correctly constructed.
  The workflow graph can be constructed a priori or can be constructed and 
  modified by intelligent Processes as the system runs.
  
  
  The Hive is based on AI concepts and modeled on the social structure and 
  behaviour of a honey bee hive. So where a worker honey bee's purpose is
  (go find pollen, bring back to hive, drop off pollen, repeat), an ensembl-hive 
  worker's purpose is (find a job, create a Process for that job, run it,
  drop off output job(s), repeat).  While most workflow systems are based 
  on 'smart' central controllers and external control of 'dumb' processes, 
  the Hive is based on 'dumb' workflow graphs and job kiosk, and 'smart' workers 
  (autonomous agents) who are self configuring and figure out for themselves what 
  needs to be done, and then do it.  The workers are based around a set of 
  emergent behaviour rules which allow a predictible system behaviour to emerge 
  from what otherwise might appear at first glance to be a chaotic system. There 
  is an inherent asynchronous disconnect between one worker and the next.  
  Work (or jobs) are simply 'posted' on a blackboard or kiosk within the hive 
  database where other workers can find them.  
  The emergent behaviour rules of a worker are:
     1) If a job is posted, someone needs to do it.
     2) Don't grab something that someone else is working on
     3) Don't grab more than you can handle
     4) If you grab a job, it needs to be finished correctly
     5) Keep busy doing work
     6) If you fail, do the best you can to report back
  For further reading on the AI principles employed in this design see:
     http://en.wikipedia.org/wiki/Autonomous_Agent
     http://en.wikipedia.org/wiki/Emergence
  

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=head1 APPENDIX

  The rest of the documentation details each of the object methods. 
  Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Hive::Process;

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception ('throw');
use Bio::EnsEMBL::Hive::Utils ('url2dbconn_hash');
#use Bio::EnsEMBL::Hive::AnalysisJob;

use base ('Bio::EnsEMBL::Utils::Exception');   # provide these methods for deriving classes

sub new {
  my ($class,@args) = @_;
  my $self = bless {}, $class;
  
  my ($analysis) = rearrange([qw( ANALYSIS )], @args);
  $self->analysis($analysis) if($analysis);
  
  return $self;
}


##########################################
#
# methods subclasses should override 
# in order to give this process function
#
##########################################

=head2 strict_hash_format

    Title   :  strict_hash_format
    Function:  if a subclass wants more flexibility in parsing job.input_id and analysis.parameters,
               it should redefine this method to return 0

=cut

sub strict_hash_format {
    return 1;
}


=head2 param_defaults

    Title   :  param_defaults
    Function:  sublcass can define defaults for all params used by the RunnableDB/Process

=cut

sub param_defaults {
    return {};
}


=head2 fetch_input

    Title   :  fetch_input
    Function:  sublcass can implement functions related to data fetching.
               Typical acivities would be to parse $self->input_id and read
               configuration information from $self->analysis.  Subclasses
               may also want to fetch data from databases or from files 
               within this function.

=cut

sub fetch_input {
    my $self = shift;

    return 1;
}

=head2 run

    Title   :  run
    Function:  sublcass can implement functions related to process execution.
               Typical activities include running external programs or running
               algorithms by calling perl methods.  Process may also choose to
               parse results into memory if an external program was used.

=cut

sub run {
    my $self = shift;

    return 1;
}

=head2 write_output

    Title   :  write_output
    Function:  sublcass can implement functions related to storing results.
               Typical activities including writing results into database tables
               or into files on a shared filesystem.
               
=cut

sub write_output {
    my $self = shift;

    return 1;
}

=head2 DESTROY

    Title   :  DESTROY
    Function:  sublcass can implement functions related to cleanup and release.
               Typical activities includes freeing datastructures or 
	       closing files. 

=cut

sub DESTROY {
    my $self = shift;

    $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}


######################################################
#
# methods that subclasses can use to get access
# to hive infrastructure
#
######################################################


=head2 queen

    Title   :   queen
    Usage   :   my $hiveDBA = $self->queen;
    Function:   returns the 'Queen' this Process was created by
    Returns :   Bio::EnsEMBL::Hive::Queen

=cut

sub queen {
    my $self = shift;

    $self->{'_queen'} = shift if(@_);
    return $self->{'_queen'};
}

sub worker {
    my $self = shift;

    $self->{'_worker'} = shift if(@_);
    return $self->{'_worker'};
}

=head2 db

    Title   :   db
    Usage   :   my $hiveDBA = $self->db;
    Function:   returns DBAdaptor to Hive database
    Returns :   Bio::EnsEMBL::Hive::DBSQL::DBAdaptor

=cut

sub db {
    my $self = shift;

    return $self->queen && $self->queen->db;
}


=head2 dbc

    Title   :   dbc
    Usage   :   my $hiveDBConnection = $self->dbc;
    Function:   returns DBConnection to Hive database
    Returns :   Bio::EnsEMBL::DBSQL::DBConnection

=cut

sub dbc {
    my $self = shift;

    return $self->queen && $self->queen->dbc;
}


=head2 data_dbc

    Title   :   data_dbc
    Usage   :   my $data_dbc = $self->data_dbc;
    Function:   returns a Bio::EnsEMBL::DBSQL::DBConnection object (the "current" one by default, but can be set up otherwise)
    Returns :   Bio::EnsEMBL::DBSQL::DBConnection

=cut

sub data_dbc {
    my $self = shift;

    if(@_ or !$self->{'_data_dbc'}) {
        $self->{'_data_dbc'} = $self->go_figure_dbc( shift @_ || $self->param('db_conn') || $self->dbc );
    }

    return $self->{'_data_dbc'};
}


sub go_figure_dbc {
    my ($self, $foo) = @_;

    if(UNIVERSAL::isa($foo, 'Bio::EnsEMBL::DBSQL::DBConnection')) { # already a DBConnection, return it:

        return $foo;

    } elsif(UNIVERSAL::can($foo, 'dbc') and UNIVERSAL::isa($foo->dbc, 'Bio::EnsEMBL::DBSQL::DBConnection')) {

        return $foo->dbc;

    } elsif(UNIVERSAL::can($foo, 'db') and UNIVERSAL::can($foo->db, 'dbc') and UNIVERSAL::isa($foo->db->dbc, 'Bio::EnsEMBL::DBSQL::DBConnection')) { # another data adaptor or Runnable:

        return $foo->db->dbc;

    } elsif(my $db_conn = (ref($foo) eq 'HASH') ? $foo : url2dbconn_hash( $foo ) ) {  # either a hash or a URL that translates into a hash

        return Bio::EnsEMBL::DBSQL::DBConnection->new( %$db_conn );

    } else {
        unless(ref($foo)) {    # maybe it is simply a registry key?
            my $dba;
            eval {
                $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($foo, 'hive');     # We should not assume it is necessarily a Hive database. It would be sufficient just to get a DBConnection from it
            };
            if(UNIVERSAL::can($dba, 'dbc')) {
                return $dba->dbc;
            }
        }
        die "Sorry, could not figure out how to make a DBConnection object out of '$foo'";
    }
}


=head2 analysis

    Title   :  analysis
    Usage   :  $self->analysis;
    Function:  Returns the Analysis object associated with this
               instance of the Process.
    Returns :  Bio::EnsEMBL::Analysis object

=cut

sub analysis {
  my ($self, $analysis) = @_;

  if($analysis) {
    throw("Not a Bio::EnsEMBL::Analysis object")
      unless ($analysis->isa("Bio::EnsEMBL::Analysis"));
    $self->{'_analysis'} = $analysis;
  }
  return $self->{'_analysis'};
}

=head2 input_job

    Title   :  input_job
    Function:  Returns the AnalysisJob to be run by this process
               Subclasses should treat this as a read_only object.          
    Returns :  Bio::EnsEMBL::Hive::AnalysisJob object

=cut

sub input_job {
  my( $self, $job ) = @_;
  if($job) {
    throw("Not a Bio::EnsEMBL::Hive::AnalysisJob object")
        unless ($job->isa("Bio::EnsEMBL::Hive::AnalysisJob"));
    $self->{'_input_job'} = $job;
  }
  return $self->{'_input_job'};
}


# ##################### subroutines that link through to Job's methods #########################

sub input_id {
    my $self = shift;

    return '' unless($self->input_job);
    return $self->input_job->input_id(@_);
}

sub param {
    my $self = shift @_;

    return $self->input_job->param(@_);
}

sub param_substitute {
    my $self = shift @_;

    return $self->input_job->param_substitute(@_);
}

sub warning {
    my $self = shift @_;

    return $self->input_job->warning(@_);
}

sub dataflow_output_id {
    my $self = shift @_;

    return $self->input_job->dataflow_output_id(@_);
}


=head2 debug

    Title   :  debug
    Function:  Gets/sets flag for debug level. Set through Worker/runWorker.pl
               Subclasses should treat as a read_only variable.
    Returns :  integer

=cut

sub debug {
  my $self = shift;
  $self->{'_debug'} = shift if(@_);
  $self->{'_debug'}=0 unless(defined($self->{'_debug'}));  
  return $self->{'_debug'};
}


=head2 worker_temp_directory

    Title   :  worker_temp_directory
    Function:  Returns a path to a directory on the local /tmp disk 
               which the subclass can use as temporary file space.
               This directory is made the first time the function is called.
               It persists for as long as the worker is alive.  This allows
               multiple jobs run by the worker to potentially share temp data.
               For example the worker (which is a single Analysis) might need
               to dump a datafile file which is needed by all jobs run through 
               this analysis.  The process can first check the worker_temp_directory
               for the file and dump it if it is missing.  This way the first job
               run by the worker will do the dump, but subsequent jobs can reuse the 
               file.
    Usage   :  $tmp_dir = $self->worker_temp_directory;
    Returns :  <string> path to a local (/tmp) directory 

=cut

sub worker_temp_directory {
  my $self = shift;
  return undef unless($self->worker);
  return $self->worker->worker_process_temp_directory;
}

#################################################
#
# methods to make porting from RunnableDB easier
#
#################################################

sub parameters {
  my $self = shift;
  return '' unless($self->analysis);
  return $self->analysis->parameters;
}

=head2 runnable

    Title   :   runnable
    Usage   :   $self->runnable($arg)
    Function:   Sets a runnable for this RunnableDB
    Returns :   arrayref of Bio::EnsEMBL::Analysis::Runnable
    Args    :   Bio::EnsEMBL::Analysis::Runnable

=cut


sub runnable {
  my ($self,$arg) = @_;

  if (!defined($self->{'runnable'})) {
      $self->{'runnable'} = [];
  }
  
  if (defined($arg)) {
    if ($arg->isa("Bio::EnsEMBL::Analysis::Runnable")) {
      push(@{$self->{'runnable'}},$arg);
    } else {
      throw("[$arg] is not a Bio::EnsEMBL::Analysis::Runnable");
    }
  }
  return $self->{'runnable'};  
}

=head2 output

    Title   :   output
    Usage   :   $self->output()
    Function:   
    Returns :   Array of Bio::EnsEMBL::FeaturePair
    Args    :   None

=cut

sub output {
  my ($self) = @_;

  unless (defined $self->{'output'}) {
    $self->{'output'} = [];
    foreach my $r (@{$self->runnable}){
      push(@{$self->{'output'}}, @{$r->output});
    }
  }

  return @{$self->{'output'}};
}

=head2 check_if_exit_cleanly

    Title   :   check_if_exit_cleanly
    Usage   :   $self->check_if_exit_cleanly()
    Function:   Check if we want to exit or kill it cleanly at the
                runnable level
    Returns :   None
    Args    :   None

=cut

sub check_if_exit_cleanly {
  my $self = shift;

  my $honeycomb_dir = $self->{'honeycomb_dir'} or return;
  $honeycomb_dir =~ s/\/$//;

  my $job_id = $self->input_job->dbID;

  my $not_allowed = $honeycomb_dir . "/" . "relegate." . $job_id;
  my $exit_cleanly = $honeycomb_dir . "/" . "relegate.all";
  if (-e $not_allowed) {
    $self->update_status('FAILED');
    throw("This job has been relegated to be killed - $job_id\n");
  } elsif (-e $exit_cleanly) {
    $self->update_status('READY');
    throw("This job has been relegated to be exited - $job_id\n");
  }
  return undef;
}

1;

