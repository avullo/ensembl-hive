
=pod 

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::LongMult::DigitFactory

=head1 SYNOPSIS

Please refer to Bio::EnsEMBL::Hive::PipeConfig::LongMult_conf pipeline configuration file
to understand how this particular example pipeline is configured and ran.

=head1 DESCRIPTION

'LongMult::DigitFactory' is the first step of the LongMult example pipeline that multiplies two long numbers.

It takes apart the second multiplier and creates several 'LongMult::PartMultiply' jobs
that correspond to the different digits of the second multiplier.

It also "flows into" one 'LongMult::AddTogether' job that will wait until 'LongMult::PartMultiply' jobs
complete and will arrive at the final result.

=cut

package Bio::EnsEMBL::Hive::RunnableDB::LongMult::DigitFactory;

use strict;

use base ('Bio::EnsEMBL::Hive::Process');

=head2 fetch_input

    Description : Implements fetch_input() interface method of Bio::EnsEMBL::Hive::Process that is used to read in parameters and load data.
                  Here the task of fetch_input() is to read in the two multipliers, split the second one into digits and create a set of input_ids that will be used later.

    param('b_multiplier'):  The second long number (a string of digits - doesn't have to fit a register)

    param('take_time'):     How much time to spend sleeping (seconds).

=cut

sub fetch_input {
    my $self = shift @_;

    my $b_multiplier    = $self->param_required('b_multiplier');

    my %digit_hash = ();
    foreach my $digit (split(//,$b_multiplier)) {
        next if (($digit eq '0') or ($digit eq '1'));
        $digit_hash{$digit}++;
    }

        # output_ids of partial multiplications to be computed:
    my @output_ids = map { { 'digit' => $_ } } keys %digit_hash;

        # store them for future use:
    $self->param('output_ids', \@output_ids);
}


=head2 run

    Description : Implements run() interface method of Bio::EnsEMBL::Hive::Process that is used to perform the main bulk of the job (minus input and output).
                  Here we don't have any real work to do, just input and output, so run() just spends some time waiting.

=cut

sub run {
    my $self = shift @_;

    sleep( $self->param('take_time') );
}


=head2 write_output

    Description : Implements write_output() interface method of Bio::EnsEMBL::Hive::Process that is used to deal with job's output after the execution.
                  Here we dataflow all the partial multiplication jobs whose input_ids were generated in fetch_input() into the branch-2 ("fan out"),
                  and also dataflow the original task down branch-1 (create the "funnel job").

=cut

sub write_output {  # nothing to write out, but some dataflow to perform:
    my $self = shift @_;

    my $output_ids = $self->param('output_ids');

        # "fan out" into branch#2 first
    $self->dataflow_output_id($output_ids, 2);

    $self->warning(scalar(@$output_ids).' multiplication jobs have been created');     # warning messages get recorded into 'log_message' table

        # then flow into the branch#1 funnel; input_id would flow into branch#1 by default anyway, but we request it here explicitly:
    $self->dataflow_output_id($self->input_id, 1);
}

1;

