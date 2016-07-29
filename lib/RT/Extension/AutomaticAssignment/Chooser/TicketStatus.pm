package RT::Extension::AutomaticAssignment::Chooser::TicketStatus;
use strict;
use warnings;
use base 'RT::Extension::AutomaticAssignment::Chooser';

sub ChooseOwnerForTicket {
    my $class  = shift;
    my $ticket = shift;
    my @users  = @{ shift(@_) };
    my $config = shift;

    # for TicketStatus we only consider tickets in the same queue
    my $tickets = RT::Tickets->new($ticket->CurrentUser);
    $tickets->LimitQueue(VALUE => $ticket->Queue);

    my @all_statuses; # for trimming down the tickets to consider
    my %primary_status; # for coalescing multiple statuses at the same level
    my @rounds; # for tracking which statuses are more important than others

    # ties => [ ['new', 'open'], 'stalled' ]
    # this says find the user with the fewest number of new or open tickets.
    # if there are multiple such users, then select the one with the fewest
    # number of stalled tickets. if there are multiple again, then we pick
    # one at random
    # in this scenario, "open" is folded into "new" like so:
    #     @all_statuses = ('new', 'open', 'stalled')
    #     %primary_status = (new => 'new', open => 'new', stalled => 'stalled')
    #     @rounds = ('new', 'stalled')

    if ($config->{ties}) {
        for my $statuses (@{ $config->{ties} }) {
            if (ref($statuses)) {
                # multiple statuses at the same round (like new/open above)
                # arbitrarily map to the first status in the list (new)
                my $primary = $statuses->[0];
                push @all_statuses, @$statuses;
                push @rounds, $primary;
                $primary_status{$_} = $primary for @$statuses;
            }
            else {
                # just a single status in this round (like stalled above)
                my $status = $statuses;
                push @all_statuses, $status;
                push @rounds, $status;
                $primary_status{$status} = $status;
            }
        }
    }
    else {
        # if the config does not specify status tiebreakers,
        # then simplify by selecting the user with the fewest
        # active-status tickets. we map everything to a single
        # "active" round
        @all_statuses = $ticket->QueueObj->ActiveStatusArray;
        $primary_status{$_} = 'active' for @all_statuses;
        @rounds = 'active';
    }

    # limit to all the statuses we've seen thus far
    # we certainly don't want to look at all resolved tickets (unless
    # directed to)
    for my $status (@all_statuses) {
        $tickets->LimitStatus(VALUE => $status);
    }

    # track how many tickets are in each primary status for
    # each owner except for nobody
    my %status_by_owner;
    while (my $ticket = $tickets->Next) {
        next if $ticket->Owner = RT->Nobody->id;
        my $primary_status = $primary_status{ $ticket->Status };
        $status_by_owner{ $ticket->Owner }{ $primary_status }++;
    }

    # for each round, find the users with the least number of tickets
    # in that status. if we find just one user, we return that new owner.
    # if we find multiple, we continue on to the next round with just
    # the users who tied for the fewest number of tickets
    my @fewest;
    for my $status (@rounds) {
        @fewest = ();
        my $fewest_ticket_count;

        for my $user (@users) {
            my $count = $status_by_owner{ $user->Id }{ $status };

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

        # found exactly one user, so return this user as the owner
        if (@fewest == 1) {
            return $fewest[0];
        }
        # otherwise, continue to the next round with the users who tied for
        # fewest tickets
        else {
            @users = @fewest;
        }
    }

    # all remaining users have the exact same number of tickets by status, so
    # pick a random one
    return $fewest[rand @fewest];
}

1;

