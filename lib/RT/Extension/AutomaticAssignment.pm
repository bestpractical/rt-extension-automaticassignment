package RT::Extension::AutomaticAssignment;
use strict;
use warnings;

our $VERSION = '0.01';

RT->AddJavaScript('jquery.ui.sortable.js');

RT->AddStyleSheets("automatic-assignment.css");
RT->AddJavaScript("automatic-assignment.js");

$RT::Config::META{AutomaticAssignmentFilters}{Type} = 'ARRAY';
$RT::Config::META{AutomaticAssignmentChoosers}{Type} = 'ARRAY';

sub _LoadedClass {
    my $self      = shift;
    my $namespace = shift;
    my $name      = shift;

    my $class = "RT::Extension::AutomaticAssignment::${namespace}::$name";
    $class->require or die $UNIVERSAL::require::ERROR;
    return $class;
}

sub _UnfilteredOwnersForTicket {
    my $self   = shift;
    my $ticket = shift;

    my $users = RT::Users->new(RT->SystemUser);
    $users->LimitToPrivileged;

    return $users;
}

sub _EligibleOwnersForTicket {
    my $self   = shift;
    my $ticket = shift;
    my $config = shift;

    my $users = RT::Users->new(RT->SystemUser);
    $users->Limit(
        FIELD    => 'id',
        OPERATOR => 'NOT IN',
        VALUE    => [ RT->System->id, RT->Nobody->id ],
    );

    for my $filter (@{ $config->{filters} }) {
        my $class = $self->_LoadedClass('Filter', $filter->{_name});
        $class->FilterOwnersForTicket($ticket, $users, $filter)
            if !$class->FiltersUsersArray;
    }

    return $users;
}

sub _FilterUsersArrayForTicket {
    my $self   = shift;
    my $ticket = shift;
    my $users  = shift;
    my $config = shift;

    for my $filter (@{ $config->{filters} }) {
        my $class = $self->_LoadedClass('Filter', $filter->{_name});
        $users = $class->FilterOwnersForTicket($ticket, $users, $filter)
            if $class->FiltersUsersArray;
    }

    return $users;
}

sub _ChooseOwnerForTicket {
    my $self   = shift;
    my $ticket = shift;
    my $users  = shift;
    my $config = shift;

    my $class = $self->_LoadedClass('Chooser', $config->{chooser}{_name});
    return $class->ChooseOwnerForTicket($ticket, $users, $config->{chooser});
}

sub _ConfigForTicket {
    my $self = shift;
    my $ticket = shift;

    my $queue = $ticket->QueueObj;
    my $attr = $queue->FirstAttribute('AutomaticAssignment');
    if (!$attr || !$attr->Content) {
        RT->Logger->error("No AutomaticAssignment config defined; automatic assignment cannot occur.");
        return;
    }

    my $config = $attr->Content;

    # filters not required, since the default list is "users who can own
    # tickets in this queue"
    $config->{filters} ||= [];

    # chooser is required
    if (!$config->{chooser}) {
        RT->Logger->error("No AutomaticAssignment chooser defined for queue '$queue'; automatic assignment cannot occur.");
        return;
    }

    return $config;
}

sub OwnerForTicket {
    my $self   = shift;
    my $ticket = shift;

    my $config = $self->_ConfigForTicket($ticket);
    return if !$config;

    my $users = $self->_EligibleOwnersForTicket($ticket, $config);
    return if !$users;

    # this has to come very late due to how it's implemented as replacing
    # the collection (using rebless) with a DBIx::SearchBuilder::Union
    $users->WhoHaveRight(
        Right               => 'OwnTicket',
        Object              => $ticket,
        IncludeSystemRights => 1,
        IncludeSuperusers   => 1,
    );

    my @users = @{ $users->ItemsArrayRef };

    @users = @{ $self->_FilterUsersArrayForTicket($ticket, \@users, $config) };

    my $user = $self->_ChooseOwnerForTicket($ticket, \@users, $config);

    return $user;
}

=head1 NAME

RT-Extension-AutomaticAssignment - automatically assign tickets based on rules

=head1 INSTALLATION

RT-Extension-AutomaticAssignment requires version RT 4.2.0 or later.

=over

=item perl Makefile.PL

=item make

=item make install

This step may require root permissions.

=item Edit your /opt/rt4/etc/RT_SiteConfig.pm

Add this line:

    Plugin( "RT::Extension::AutomaticAssignment" );

You may wish to also add this line if you want to use the "Work Schedule"
filter, which exposes the RT's SLA business hours as custom field values:

    Set( @CustomFieldValuesSources, "RT::CustomFieldValues::ServiceBusinessHours" );

=item Clear your mason cache

    rm -rf /opt/rt4/var/mason_data/obj

=item Restart your webserver

=item Create scrips

You may control which circumstances automatic assignment should take place
using RT's scrips system. For example, perhaps you want an "On Create,
Automatic Assignment" scrip on some of your queues. Any tickets explicitly
created with an owner will retain that owner, but unowned tickets will use
the automatic assignment system. You may also want an "On Queue Change,
Automatic Reassignment" scrip. The "Automatic Reassignment" action is
slightly different from "Automatic Assignment" action because reassignment
will happen even if the ticket has an owner already.

You may specify as many automatic assignment and reassignment scrips as you
like. The automatic assignment admin UI will warn you, however, if it finds
no scrips.

=item Configure automatic assignment policies

Visit Admin -> Queues -> Select -> (queue) -> Automatic Assignment to
configure the automatic assignment policy for a queue.

There are two important stages to the automatic assignment policy. First,
you configure rules for deciding which users are eligible to be
automatically assigned tickets (based on time of day, group membership,
etc). Next, you configure a policy for deciding which of those eligible
users will be made the owner of each ticket (who has the fewest open
tickets, randomly, etc).

B<Filters> are policies which reduce the number of potential candidate
owners based on the specified rule. For example, the "Member of Group"
filter limits automatic assignment to only members of the selected group.
The "Work Schedule" filter allows users (or, perhaps, only their manager) to
select which business hours that they are available. You may specify zero,
one, or more filters. Each user must fulfill the requirements of I<all> the
filters to be included in automatic assignment.

B<Chooser> is the policy that automatic assignment uses to pick a single
owner from a list of many potential candidates. The most basic B<Chooser> is
"Random". A more useful Chooser is "Active Tickets": the user with the
fewest number of active tickets in the queue is assigned the ticket. The
"Round Robin" Chooser distributes tickets to each candidate owner evenly.

Each Filter and Chooser provides its documentation and configuration
directly on the automatic assignment interface.

=back

=head1 AUTHOR

Best Practical Solutions, LLC E<lt>modules@bestpractical.comE<gt>

=head1 BUGS

All bugs should be reported via email to

    L<bug-RT-Extension-AutomaticAssignment@rt.cpan.org|mailto:bug-RT-Extension-AutomaticAssignment@rt.cpan.org>

or via the web at

    L<rt.cpan.org|http://rt.cpan.org/Public/Dist/Display.html?Name=RT-Extension-AutomaticAssignment>.

=head1 COPYRIGHT

This extension is Copyright (C) 2016 Best Practical Solutions, LLC.

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut

1;
