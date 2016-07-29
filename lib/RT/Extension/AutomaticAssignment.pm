package RT::Extension::AutomaticAssignment;
use strict;
use warnings;

our $VERSION = '0.01';

sub _LoadedClass {
    my $self      = shift;
    my $namespace = shift;
    my $name      = shift;

    my $class = $name =~ /::/ ? $name : "RT::Extension::AutomaticAssignment::${namespace}::$name";
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

    for my $filter (@{ $config->{filters} }) {
        if (ref($filter) eq 'CODE') {
            $filter->($users, $ticket);
        }
        else {
            my $class = $filter->{class};
            $class->FilterOwnersForTicket($ticket, $users, $filter);
        }
    }

    return $users;
}

sub _ChooseOwnerForTicket {
    my $self   = shift;
    my $ticket = shift;
    my $users  = shift;
    my $config = shift;

    my $class = $config->{chooser}{class};
    return $class->ChooseOwnerForTicket($ticket, $users, $config->{chooser});
}

sub _ConfigForTicket {
    my $self = shift;
    my $ticket = shift;

    my $queue = $ticket->QueueObj->Name;
    my $config = RT->Config->Get('AutomaticAssignment');
    if (!$config) {
        RT->Logger->error("No AutomaticAssignment config defined; automatic assignment cannot occur.");
        return;
    }

    # merge the queue-specific config into the default config
    my %merged_config = %{ $config->{Default} || {} };
    $merged_config{ $_ } = $config->{QueueDefault}{ $queue }->{ $_ }
        for keys %{ $config->{QueueDefault}{ $queue } || {} };

    # filters not required, since the default list is "users who can own
    # tickets in this queue"
    $merged_config{filters} ||= [];

    # chooser is required
    if (!$merged_config{chooser}) {
        RT->Logger->error("No AutomaticAssignment chooser defined for queue '$queue'; automatic assignment cannot occur.");
        return;
    }

    # load each filter class
    for (@{ $merged_config{filters} }) {
        if (!ref($_)) {
            $_ = {
                class => $self->_LoadedClass('Filter', $_),
            };
        }
        elsif (ref($_) eq 'CODE') {
            # nothing to do
        }
        else {
            $_->{class} = $self->_LoadedClass('Filter', $_->{class});
        }
    }

    # load chooser class
    if (!ref($merged_config{chooser})) {
        $merged_config{chooser} = {
            class => $self->_LoadedClass('Chooser', $merged_config{chooser}),
        };
    }
    else {
        $merged_config{chooser}{class} = $self->_LoadedClass('Chooser', $merged_config{chooser}{class});
    }

    return \%merged_config;
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
    my $user = $self->_ChooseOwnerForTicket($ticket, \@users, $config);

    return $user;
}

=head1 NAME

RT-Extension-AutomaticAssignment - 

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

=item Clear your mason cache

    rm -rf /opt/rt4/var/mason_data/obj

=item Restart your webserver

=item Create scrips

This lets you control which circumstances automatic assignment should take
place. For example, perhaps you want an On Create, Automatic Assignment
scrip on some of your queues. Any tickets explicitly created with an owner
will retain that owner. You may also want an On Queue Change, Automatic
Reassignment scrip. For Automatic Reassignment, the automatic assignment
will happen even if the ticket has an owner already.

=item Configure automatic assignment policies

    Set(%AutomaticAssignment_Choosers, (
        Default => 'Random',
        QueueDefaults => {
            General => 'TicketStatus',
            Review => {
                class => 'TicketStatus',
                ties => [ ['new', 'open'], 'stalled' ],
            },
        },
    ));

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
