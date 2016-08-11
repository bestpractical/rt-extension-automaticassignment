package RT::Extension::AutomaticAssignment::Filter::MemberOfRole;
use strict;
use warnings;
use base 'RT::Extension::AutomaticAssignment::Filter';

sub FilterOwnersForTicket {
    my $class  = shift;
    my $ticket = shift;
    my $users  = shift;
    my $config = shift;

    my $role_name = $config->{name}
        or die "Unable to filter MemberOfRole; no name provided.";

    my ($ticket_group, $queue_group);

    if ($role_name eq 'AdminCc' || $role_name eq 'Cc') {
        $ticket_group = $ticket->RoleGroup($role_name);
        $queue_group = $ticket->QueueObj->RoleGroup($role_name);
    }
    elsif ($role_name eq 'Requestor' || $role_name eq 'Requestors') {
        $ticket_group = $ticket->RoleGroup('Requestor');
    }
    elsif (RT::Handle::cmp_version($RT::VERSION,'4.4.0') >= 0) {
        die "Unable to filter MemberOfRole role '$role_name'; custom roles require RT 4.4 or greater.";
    }
    else {
        my $roles = RT::CustomRoles->new( $ticket->CurrentUser );
        $roles->Limit( FIELD => 'Name', VALUE => $role_name, CASESENSITIVE => 0 );
        my $role = $roles->First;

        $ticket_group = $ticket->RoleGroup($role->GroupType);
        $queue_group = $ticket->QueueObj->RoleGroup($role->GroupType);
    }

    $users->WhoBelongToGroups(
        Groups => [ map { $_->id } grep { $_ } $ticket_group, $queue_group ],
        IncludeSubgroupMembers => 1,
        IncludeUnprivileged    => 1, # no need to LimitToPrivileged again
    );
}

sub Description { "Member of Role" }

sub CanonicalizeConfig {
    my $class = shift;
    my $input = shift;

    my $role = $input->{role};
    unless ($role eq 'Cc' || $role eq 'AdminCc' || $role eq 'Requestor') {
        $role =~ s/[^0-9]//g; # allow only numeric id
    }

    return { role => $role };
}

1;

