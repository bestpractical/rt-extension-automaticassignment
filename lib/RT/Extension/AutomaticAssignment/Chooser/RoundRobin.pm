package RT::Extension::AutomaticAssignment::Chooser::RoundRobin;
use strict;
use warnings;
use base 'RT::Extension::AutomaticAssignment::Chooser';
use List::Util 'reduce';

sub ChooseOwnerForTicket {
    my $class  = shift;
    my $ticket = shift;
    my @users  = @{ shift(@_) };
    my $config = shift;

    my $queue = $ticket->Queue;
    my $attr = 'AutomaticAssignment-RoundRobin-Queue' . $queue;

    # find the user whose last round-robin automatic assignment in this queue
    # was the longest time ago
    my $owner = reduce {
        ($a->FirstAttribute($attr)||0) < ($b->FirstAttribute($attr)||0) ? $a : $b
    } @users;

    if ($owner) {
        $owner->SetAttribute(Name => $attr, Content => time);
    }

    return $owner;
}

sub Description { "Round Robin" }

1;

