package Python::Bytecode;
use 5.6.0;

use strict;

our $VERSION = "1.00";

use overload '""' => sub { my $obj = shift; 
    "<Code object ".$obj->{name}.", file ".$obj->{filename}." line ".$obj->{lineno}." at ".sprintf('0x%x>',0+$obj);
    }, "0+" => sub { $_[0] }, fallback => 1;

sub new {
    my ($class, $fh) = (@_);
    if (ref $fh) { 
        $PyCompile::fh = $fh;
    } else {
        @PyCompile::stuff = split //, $fh;
    }

    my $magic;
    my $pycmagic = (50823 | (ord("\r")<<16) | (ord("\n")<<24));
    die "Bad magic number $magic != $pycmagic" if ($magic =r_long()) != $pycmagic;
    r_long(); # Second magic number
    our $code = r_object();
    return $code;
}

sub r_byte () { 
    if (defined @PyCompile::stuff) { ord shift @PyCompile::stuff;}
    else { ord getc $PyCompile::fh }
}

sub r_long () {
    my $x = r_byte;
    $x |= r_byte << 8;
    $x |= r_byte << 16;
    $x |= r_byte << 24;
    return $x;
}

sub r_short () {
    my $x = r_byte;
    $x |= r_byte << 8;
    $x |= -($x & 0x8000);
    return $x;
}

sub r_string { 
    my $length = r_long; 
    my $buf; 
    if (defined @PyCompile::stuff) {
        $buf = join "", splice ( @PyCompile::stuff,0,$length,() );
    } else {
        read $PyCompile::fh, $buf, $length; 
    }
    return $buf;
}

sub r_object () {
    my $type = chr r_byte();
    return r_string if $type eq "s";
    return r_code() if $type eq "c";
    return r_long() if $type eq "i";
    if ($type eq "(") {
        my @tuple = r_tuple();
        return [@tuple] unless wantarray;
        return @tuple;
    }
    return undef if $type eq "N"; # None indeed.
    die "Oops! I didn't implement ".ord $type;
}

sub r_tuple {
    my $n = r_long;
    return () unless $n;
    my @rv;
    push @rv, scalar r_object for (1..$n);
    return @rv;
}

sub r_code {
    my %x;
    $x{argcount} = r_short;
    $x{nlocals}  = r_short;
    $x{stacksize}= r_short;
    $x{flags}    = r_short;
    $x{code}     = r_object;
    $x{constants}= r_object;
    $x{names}    = r_object;
    $x{varnames} = r_object;
    $x{filename} = r_object;
    $x{name}     = r_object;
    $x{lineno}   = r_short;
    $x{lnotab}   = r_object;
    my $obj = \%x;
    bless $obj, __PACKAGE__;
    return $obj;
}

for (qw(constants argcount nlocals stacksize flags code constants names
varnames filename name lineno lnotab)) {
    no strict q/subs/;
    eval "sub $_ { return \$_[0]->{$_} }";
}

$Parrot::Bytecode::DATA = <<EOF;

# This'll amuse you. It's actually lifted directly from dis.py :)
# Instruction opcodes for compiled code

def_op('STOP_CODE', 0)
def_op('POP_TOP', 1)
def_op('ROT_TWO', 2)
def_op('ROT_THREE', 3)
def_op('DUP_TOP', 4)
def_op('ROT_FOUR', 5)

def_op('UNARY_POSITIVE', 10)
def_op('UNARY_NEGATIVE', 11)
def_op('UNARY_NOT', 12)
def_op('UNARY_CONVERT', 13)

def_op('UNARY_INVERT', 15)

def_op('BINARY_POWER', 19)

def_op('BINARY_MULTIPLY', 20)
def_op('BINARY_DIVIDE', 21)
def_op('BINARY_MODULO', 22)
def_op('BINARY_ADD', 23)
def_op('BINARY_SUBTRACT', 24)
def_op('BINARY_SUBSCR', 25)

def_op('SLICE+0', 30)
def_op('SLICE+1', 31)
def_op('SLICE+2', 32)
def_op('SLICE+3', 33)

def_op('STORE_SLICE+0', 40)
def_op('STORE_SLICE+1', 41)
def_op('STORE_SLICE+2', 42)
def_op('STORE_SLICE+3', 43)

def_op('DELETE_SLICE+0', 50)
def_op('DELETE_SLICE+1', 51)
def_op('DELETE_SLICE+2', 52)
def_op('DELETE_SLICE+3', 53)

def_op('INPLACE_ADD', 55)
def_op('INPLACE_SUBTRACT', 56)
def_op('INPLACE_MULTIPLY', 57)
def_op('INPLACE_DIVIDE', 58)
def_op('INPLACE_MODULO', 59)
def_op('STORE_SUBSCR', 60)
def_op('DELETE_SUBSCR', 61)

def_op('BINARY_LSHIFT', 62)
def_op('BINARY_RSHIFT', 63)
def_op('BINARY_AND', 64)
def_op('BINARY_XOR', 65)
def_op('BINARY_OR', 66)
def_op('INPLACE_POWER', 67)

def_op('PRINT_EXPR', 70)
def_op('PRINT_ITEM', 71)
def_op('PRINT_NEWLINE', 72)
def_op('PRINT_ITEM_TO', 73)
def_op('PRINT_NEWLINE_TO', 74)
def_op('INPLACE_LSHIFT', 75)
def_op('INPLACE_RSHIFT', 76)
def_op('INPLACE_AND', 77)
def_op('INPLACE_XOR', 78)
def_op('INPLACE_OR', 79)
def_op('BREAK_LOOP', 80)

def_op('LOAD_LOCALS', 82)
def_op('RETURN_VALUE', 83)
def_op('IMPORT_STAR', 84)
def_op('EXEC_STMT', 85)

def_op('POP_BLOCK', 87)
def_op('END_FINALLY', 88)
def_op('BUILD_CLASS', 89)

HAVE_ARGUMENT = 90      # Opcodes from here have an argument:

name_op('STORE_NAME', 90)   # Index in name list
name_op('DELETE_NAME', 91)  # ""
def_op('UNPACK_SEQUENCE', 92)   # Number of tuple items

name_op('STORE_ATTR', 95)   # Index in name list
name_op('DELETE_ATTR', 96)  # ""
name_op('STORE_GLOBAL', 97) # ""
name_op('DELETE_GLOBAL', 98)    # ""
def_op('DUP_TOPX', 99)      # number of items to duplicate
def_op('LOAD_CONST', 100)   # Index in const list
hasconst.append(100)
name_op('LOAD_NAME', 101)   # Index in name list
def_op('BUILD_TUPLE', 102)  # Number of tuple items
def_op('BUILD_LIST', 103)   # Number of list items
def_op('BUILD_MAP', 104)    # Always zero for now
name_op('LOAD_ATTR', 105)   # Index in name list
def_op('COMPARE_OP', 106)   # Comparison operator
hascompare.append(106)
name_op('IMPORT_NAME', 107) # Index in name list
name_op('IMPORT_FROM', 108) # Index in name list

jrel_op('JUMP_FORWARD', 110)    # Number of bytes to skip
jrel_op('JUMP_IF_FALSE', 111)   # ""
jrel_op('JUMP_IF_TRUE', 112)    # ""
jabs_op('JUMP_ABSOLUTE', 113)   # Target byte offset from beginning of code
jrel_op('FOR_LOOP', 114)    # Number of bytes to skip

name_op('LOAD_GLOBAL', 116) # Index in name list

jrel_op('SETUP_LOOP', 120)  # Distance to target address
jrel_op('SETUP_EXCEPT', 121)    # ""
jrel_op('SETUP_FINALLY', 122)   # ""

def_op('LOAD_FAST', 124)    # Local variable number
haslocal.append(124)
def_op('STORE_FAST', 125)   # Local variable number
haslocal.append(125)
def_op('DELETE_FAST', 126)  # Local variable number
haslocal.append(126)

def_op('SET_LINENO', 127)   # Current line number
SET_LINENO = 127

def_op('RAISE_VARARGS', 130)    # Number of raise arguments (1, 2, or 3)
def_op('CALL_FUNCTION', 131)    # #args + (#kwargs << 8)
def_op('MAKE_FUNCTION', 132)    # Number of args with default values
def_op('BUILD_SLICE', 133)      # Number of items

def_op('CALL_FUNCTION_VAR', 140)     # #args + (#kwargs << 8)
def_op('CALL_FUNCTION_KW', 141)      # #args + (#kwargs << 8)
def_op('CALL_FUNCTION_VAR_KW', 142)  # #args + (#kwargs << 8)

def_op('EXTENDED_ARG', 143)
EXTENDED_ARG = 143

EOF

# Set up op code data structures
my @opnames;
my %c; # Natty constants.
my %has;
for (split /\n/, $Parrot::Bytecode::DATA) {
    next if /^#/ or not /\S/;
    if    (/^def_op\('([^']+)', (\d+)\)/) { $opnames[$2]=$1; } 
    elsif (/^(jrel|jabs|name)_op\('([^']+)', (\d+)\)/) { $opnames[$3]=$2; $has{$1}{$3}++ } 
    elsif (/(\w+)\s*=\s*(\d+)/) { $c{$1}=$2; }
    elsif (/^has(\w+)\.append\((\d+)\)/) { $has{$1}{$2}++ }
}

# Now we've read in the op tree, disassemble it.

sub findlabels {
    my %labels = ();
    my @code = @_;
    my $offset = 0;
    while (@code) {
        my $c = shift @code;
        $offset++;
        if ($c>=$c{HAVE_ARGUMENT}) {
            my $arg = shift @code; 
            $arg += (256 * shift (@code));
            $offset += 2;
            if ($has{jrel}{$c}) { $labels{$offset + $arg}++ };
            if ($has{jabs}{$c}) { $labels{$offset}++ };
        }
    }
    return %labels; 
}

my @cmp_op   = ('<', '<=', '==', '!=', '>', '>=', 'in', 'not in', 'is', 'is not', 'exception match', 'BAD');

sub disassemble {
    my @code = map { ord } split //, $_[0]->{code};
    my %labels = findlabels(@code);
    my $offset = 0;
    my $extarg = 0;
    my @dis;
    while (@code) {
        my $c = shift @code;
        my $text = (($labels{$offset}) ? ">>" : "  ");
        $text .= sprintf "%4i", $offset;
        $text .= sprintf "%20s", $opnames[$c];
        $offset++;
        my $arg;
        if ($c>=$c{HAVE_ARGUMENT}) {
            $arg = shift @code; 
            $arg += (256 * shift (@code)) + $extarg;
            $extarg = 0;
            $extarg = $arg * 65535 if ($c == $c{EXTENDED_ARG});
            $offset+=2;
            $text .= sprintf "%5i", $arg;
            $text .= " (".$_[0]->{constants}->[$arg].")" if ($has{const}{$c});
            $text .= " (".$_[0]->{varnames}->[$arg].")"  if ($has{"local"}{$c});
            $text .= " [".$_[0]->{names}->[$arg]."]"     if ($has{name}{$c});
            $text .= " [".$cmp_op[$arg]."]"              if ($has{compare}{$c});
            $text .= " (to ".($offset+$arg).")"          if ($has{jrel}{$c});
        }
        push @dis, [$text, $c, $arg];
    }
    return @dis;
}

sub name { $opnames[$_[0]] }

1;

=head1 NAME

Python::Bytecode - Disassemble and investigate Python bytecode

=head1 SYNOPSIS

    use Python::Bytecode
    my $bytecode = Python::Bytecode->new($bytecode);
    my $bytecode = Python::Bytecode->new(FH);
    for ($bytecode->disassemble) {
        print $_->[0],"\n"; # Textual representation of disassembly
    }

=head1 DESCRIPTION

C<Python::Bytecode> accepts a string or filehandle contain Python
bytecode and puts it into a format you can manipulate.

=head1 METHODS

=over 3

=item C<disassemble>

This is the basic method for getting at the actual code. It returns an 
array representing the individual operations in the bytecode stream.
Each element is a reference to a three-element array containing
a textual representation of the disassembly, the opcode number, (the
C<name()> function can be used to turn this into an op name) and
the argument to the op, if any.

=item C<constants>

This returns an array reflecting the constants table of the bytecode.
Some operations such as C<LOAD_CONST> refer to constants by index in
this array.

=item C<labels>

Similar to C<constants>, some operations branch to labels by index
in this table.

=item C<varnames>

Again, when variables are referred to by name, the names are stored
as an index into this table.

=item C<filename>

The filename from which this compiled bytecode is derived.

=back

There are other methods, but you can read the code to find them. It's
not hard, and besides, it's probably easiest to work off the textual
representation of the disassembly anyway.

=head1 PERPETRATOR

Simon Cozens, C<simon@cpan.org>

=head1 LICENSE

This code is licensed under the same terms as Perl itself.

