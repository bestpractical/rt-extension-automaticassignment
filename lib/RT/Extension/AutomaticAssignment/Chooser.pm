package RT::Extension::AutomaticAssignment::Chooser;
use strict;
use warnings;
use base 'RT::Base';

sub ChooseOwnerForTicket {
    my $self = shift;
    die "Subclass " . ref($self) . " of " . __PACKAGE__ . " does not implement required method ChooseOwnerForTicket";
}

1;

