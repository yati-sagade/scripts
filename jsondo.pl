use strict;
use warnings;
use feature qw(say);

use JSON::XS qw(decode_json);
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use File::Slurp qw(read_file);

my %opts;
GetOptions(\%opts,
    'callback|c=s',
    'input|i=s',
    'help|h',
) or pod2usage( -verbose => 1, -exitval => 1 );

if ( $opts{help} ) {
    pod2usage( -verbose => 1, -exitval => 0 );
}

my $callback = $opts{callback};
my $input    = $opts{input} || \*STDIN;

my $content  = read_file( $input );

my $obj;
eval {
    $obj = decode_json( $content );
    1;
} or do {
    my $err = $@;
    say STDERR 'Error parsing JSON: '.$err;
    exit 1;
};

my $callback_func;
if ( $callback ) {
    $callback_func = eval 'sub { '.$callback.' }';
    my $err = $@;
    if ( !$callback_func and $err ) {
        say STDERR 'Error in callback code: '.$err;
        exit 1;
    }
}

$callback_func ||= sub {
    my $arg = shift;
    say Dumper $arg;
};

{
    local $_ = $obj;
    local $obj = $obj;
    $callback_func->($obj);
}


=pod

=head1 NAME

jsondo.pl - Parse a file or standard input as json and have a callback called.

=head1 SYNOPSIS

    perl jsondo.pl FILENAME -c 'print $_->{descend}{down}{a}{tree}'

=head1 DESCRIPTION

This is a small script that does the equivalent of:
    
    perl -Mstrict -MJSON::XS=decode_json -MFile::Slurp=read_file -wlE '
        my $json = decode_json(read_file("..."));
        # do something with $json
    '
except with some error handling. C<$_> and C<$obj> are both bound to the parsed
JSON object (if one could be parsed), and hence this can be used in the callback
code:

    perl jsondo.pl -c 'my @event_kinds=(...); my $sum=0; $sum += $obj->{data}{events}{$_} for @event_kinds; say $sum;'

=head1 OPTIONS

=over

=item -h,--help

Show this message and quit.

=item -i,--input FILENAME

Path to the input JSON file. Read from the standard input if not given.

=item -c,--callback CODE

Perl code that is wrapped in a string and executed with C<$obj> and C<$_> both
bound to the parsed JSON object.

=back

=cut
