package Bio::EnsEMBL::Hive::Cacheable;

use Data::Dumper;
use Bio::EnsEMBL::Hive::Utils ('stringify');
use Bio::EnsEMBL::Hive::Utils::Collection;

our $cache_by_class;    # global Hash-of-Hashes


sub collection {
    my $class = shift @_;

    if(@_) {
        $cache_by_class{$class} = shift @_;
    }

    return $cache_by_class{$class};
}


sub unikey {    # to be redefined by individual Cacheable classes
    return undef;
}


sub add_new_or_update {
    my $class = shift @_;

    my $self;

    if( my $unikey_keys = $class->unikey() ) {
        my %all_pairs = @_;
        my %unikey_pairs;
        @unikey_pairs{ @$unikey_keys} = @all_pairs{ @$unikey_keys };
        use Data::Dumper;
        local $Data::Dumper::Indent    = 0;         # we want everything on one line
        local $Data::Dumper::Terse     = 1;         # and we want it without dummy variable names
        local $Data::Dumper::Maxdepth  = 1;

        if( $self = $class->collection()->find_one_by( %unikey_pairs ) ) {
            # update the rest of the fields
            warn "Updating $class (".Dumper(\%unikey_pairs).")\n";
            while( my ($method, $value) = each %all_pairs ) {
                unless( exists( $unikey_pairs{$method} ) ) {
                    $self->$method($value);
                }
            }
        } else {
            warn "Creating a new $class (".Dumper(\%unikey_pairs).")\n";
        }
    } else {
        warn "$class doesn't redefine unikey(), so unique objects cannot be identified";
    }

    unless( $self ) {
        $self = $class->new( @_ );
        $class->collection()->add( $self );
    }

    return $self;
}


1;
