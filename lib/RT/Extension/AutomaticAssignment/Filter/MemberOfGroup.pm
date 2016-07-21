package RT::Extension::AutomaticAssignment::Filter::MemberOfGroup;
use strict;
use warnings;
use base 'RT::Extension::AutomaticAssignment::Filter';

sub FilterOwnersForTicket {
    my $class  = shift;
    my $ticket = shift;
    my $users  = shift;
    my $config = shift;

    my $group_name = $config->{name}
        or die "Unable to filter MemberOfGroup; no name provided.";

    my $group = RT::Group->new($ticket->CurrentUser);
    $group->LoadUserDefinedGroup($group_name);

    if (!$group->Id) {
        die "Unable to filter MemberOfGroup; can't load group '$group_name'";
    }

    $users->MemberOfGroup($group->Id);
}

1;

