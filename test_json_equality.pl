use strict;
use warnings;
use feature qw(say);
use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);
use Data::Compare;
use Data::Dumper;
use List::Util qw(all);
use Scalar::Util qw(looks_like_number);

my $file1 = shift or die 'Need file 1';
my $file2 = shift or die 'Need file 2';

my $data1 = decode_json( read_file( $file1 ) );
my $data2 = decode_json( read_file( $file2 ) );

if ( are_things_about_the_same($data1, $data2) ) {
    say "pass";
    exit 0;
}

if ( scalar @$data1 != scalar @$data2 ) {
    printf "mismatch in length (%d vs %d)\n", scalar @$data1, scalar @$data2;
    exit 1;
}

for my $idx ( 0..$#$data1 ) {
    my ( $d1, $d2 ) = ( $data1->[$idx], $data2->[$idx] );
    if ( !are_things_about_the_same( $d1, $d2 ) ) {
        say "Index $idx mismatch:";
        say Dumper $d1;
        say Dumper $d2;

        printf "keys: %d vs %d\n", scalar keys %$d1, scalar keys %$d2;
        last;
    }
}

sub are_things_about_the_same {
    my ($a, $b, @path) = @_;


    $a //= {};
    $b //= {};

    if ( ref $a ne ref $b ) {
        say "ref a(".ref($a).") is not the same as ref b(".ref($b).")";
        return 0;
    }

    if (ref $a eq 'ARRAY') {
        unless (scalar @$a == scalar @$b) {
            say "lengths of arrays don't match";
            return 0;
        }
        return all { are_things_about_the_same($a->[$_], $b->[$_], @path, "[$_]") } (0..$#$a);
    }

    if (ref $a eq 'HASH') {
        unless (scalar keys %$a == scalar keys %$b) {
            say "@path: differing number of keys in hashes";
            return 0;
        }
        my $sortkeysa = [sort keys %$a];
        my $sortkeysb = [sort keys %$b];
        unless (Compare($sortkeysa, $sortkeysb)) {
            my $a_minus_b = [grep !exists $b->{$_}, keys %$a];
            my $b_minus_a = [grep !exists $a->{$_}, keys %$b];
            say "@path: differing set of keys in hashes. local~remote: ".Dumper($a_minus_b).", remote~local:".Dumper($b_minus_a);
            return 0;
        }
        return all { are_things_about_the_same($a->{$_}, $b->{$_}, @path, "{$_}") } (keys %$a);
    }

    die 'Cannot handle ref '.ref($a) if ref $a;

    if (looks_like_number($a)) {
        my $min = $a < $b ? $a : $b;
        if (abs($a - $b)/(abs($min)+1) > 0.05) {
            say "@path: numbers $a and $b are too different";
            return 0;
        }
        return 1;
    }

    if ( $a ne $b ) {
        say "'$a' ne '$b'";
        return 0;
    }

    return 1;
}
