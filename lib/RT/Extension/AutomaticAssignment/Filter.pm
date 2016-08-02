package RT::Extension::AutomaticAssignment::Filter;
use strict;
use warnings;
use base 'RT::Base';

sub FilterOwnersForTicket {
    my $self = shift;
    die "Subclass " . ref($self) . " of " . __PACKAGE__ . " does not implement required method FilterOwnersForTicket";
}

sub FiltersUsersArray {
    return 0;
}

1;


