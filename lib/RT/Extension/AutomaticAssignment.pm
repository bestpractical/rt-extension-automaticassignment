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

    return $users->[rand @$users];
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
