package RT::Extension::AutomaticAssignment::Filter::MemberOfGroup;
use strict;
use warnings;
use base 'RT::Extension::AutomaticAssignment::Filter';

sub FilterOwnersForTicket {
    my $class  = shift;
    my $ticket = shift;
    my $users  = shift;
    my $config = shift;

    my $group_name;

    if ($config->{name}) {
        $group_name = $config->{name};
    }
    elsif ($config->{queue_cf}) {
        $group_name = $ticket->QueueObj->FirstCustomFieldValue($config->{queue_cf});
    }
    else {
        die "Unable to filter MemberOfGroup; no name or queue_cf provided.";
    }

    my $group = RT::Group->new($ticket->CurrentUser);
    $group->LoadUserDefinedGroup($group_name);

    if (!$group->Id) {
        die "Unable to filter MemberOfGroup; can't load group '$group_name'";
    }

    $users->MemberOfGroup($group->Id);
}

1;

