package RT::Extension::AutomaticAssignment::Chooser::Random;
use strict;
use warnings;
use base 'RT::Extension::AutomaticAssignment::Chooser';

sub ChooseOwnerForTicket {
    my $class  = shift;
    my $ticket = shift;
    my $users  = shift;
    my $config = shift;

    return $users->[rand @$users];
}

1;

