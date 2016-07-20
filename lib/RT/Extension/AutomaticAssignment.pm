use strict;
use warnings;
package RT::Extension::AutomaticAssignment;

our $VERSION = '0.01';

sub AvailableOwnersForTicket {
    my $class  = shift;
    my $ticket = shift;

    my $users = RT::Users->new(RT->SystemUser);
    $users->LimitToPrivileged;
    return $users->ItemsArrayRef;
}

sub ChooseOwnerForTicket {
    my $class  = shift;
    my $ticket = shift;
    my $users  = shift;

    my $queue = $ticket->QueueObj->Name;
    my $choosers = RT->Config->Get('AutomaticAssignment_Choosers');
    if (!$choosers) {
        RT->Logger->error("No AutomaticAssignment_Choosers defined; automatic assignment cannot occur.");
        return;
    }

    my $config = $choosers->{QueueDefault}{ $queue } || $choosers->{Default};
    my $chooser_name;

    if (!$config) {
        RT->Logger->error("No AutomaticAssignment_Choosers Default or QueueDefault for queue '$queue' defined; automatic assignment cannot occur.");
        return;
    }

    if (ref($config)) {
        $chooser_name = $config->{class};
    }
    else {
        $chooser_name = $config;
        $config = {};
    }

    my $chooser_class = $chooser_name =~ /::/ ? $chooser_name : "RT::Extension::AutomaticAssignment::Chooser::$chooser_name";
    $chooser_class->require or die $UNIVERSAL::require::ERROR;
    return $chooser_class->ChooseOwnerForTicket($ticket, $users, $config);
}

sub OwnerForTicket {
    my $class  = shift;
    my $ticket = shift;

    my $users = $class->AvailableOwnersForTicket($ticket);
    return if !$users;

    my $user = $class->ChooseOwnerForTicket($ticket, $users);

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
            General => 'Ownership',
            Review => {
                class => 'Ownership',
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
