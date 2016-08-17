package RT::Extension::AutomaticAssignment::Chooser::ActiveTickets;
use strict;
use warnings;
use base 'RT::Extension::AutomaticAssignment::Chooser';

sub ChooseOwnerForTicket {
    my $class  = shift;
    my $ticket = shift;
    my @users  = @{ shift(@_) };
    my $config = shift;

    # for ActiveTickets we only consider tickets in the same queue
    my $tickets = RT::Tickets->new($ticket->CurrentUser);
    $tickets->LimitQueue(VALUE => $ticket->Queue);

    $tickets->LimitToActiveStatus;

    # track how many tickets are in each active status for
    # each owner except for nobody
    my %by_owner;
    while (my $ticket = $tickets->Next) {
        next if $ticket->Owner == RT->Nobody->id;
        $by_owner{ $ticket->Owner }++;
    }

    my $fewest_ticket_count;
    my @fewest;

    for my $user (@users) {
        my $count = $by_owner{ $user->Id } || 0;

        # either the first user we've seen, or this user
        # has fewer tickets than anyone else we've seen this round
        if (!defined($fewest_ticket_count) || $count < $fewest_ticket_count) {
            @fewest = $user;
            $fewest_ticket_count = $count;
        }
        elsif ($count == $fewest_ticket_count) {
            push @fewest, $user;
        }
    }

    # all remaining users have the exact same number of active tickets, so
    # pick a random one. if there is only one remaining, it will still pick
    # that one
    return $fewest[rand @fewest];
}

sub Description { "Active Tickets" }

1;

