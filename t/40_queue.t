use strict;
use warnings;
use Test::More;
use Test::Exception;

use PICA::Modification::Queue;
use PICA::Modification::TestQueue;

throws_ok { PICA::Modification::Queue->new('foo'); } 
    qr{PICA/Modification/Queue/Foo\.pm};

my $queue = PICA::Modification::Queue->new('hash');

test_queue $queue, 'PICA::Modification::Queue::Hash';

done_testing;
