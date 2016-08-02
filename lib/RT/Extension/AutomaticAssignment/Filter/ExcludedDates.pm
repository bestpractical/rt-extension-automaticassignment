package RT::Extension::AutomaticAssignment::Filter::ExcludedDates;
use strict;
use warnings;
use base 'RT::Extension::AutomaticAssignment::Filter';

sub _UserCF {
    my $class = shift;
    my $name = shift;

    my $cf = RT::CustomField->new(RT->SystemUser);
    $cf->LoadByName(
        Name       => $name,
        LookupType => RT::User->CustomFieldLookupType,
    );
    if (!$cf->Id) {
        die "Unable to load User Custom Field named '$name'";
    }
    return $cf;
}

sub FilterOwnersForTicket {
    my $class  = shift;
    my $ticket = shift;
    my $users  = shift;
    my $config = shift;

    my $now = RT::Date->new(RT->SystemUser);
    $now->SetToNow;

    if ($config->{except_between}) {
        my ($start_name, $end_name) = @{ $config->{except_between} };
        my $start_cf = $class->_UserCF($start_name);
        my $end_cf = $class->_UserCF($end_name);

        my $subclause = $start_name . '-' . $end_name;

        # allow users for whom start/end is null
        $users->LimitCustomField(
            SUBCLAUSE       => "$subclause-begin",
            CUSTOMFIELD     => $start_cf->Id,
            COLUMN          => 'Content',
            OPERATOR        => 'IS',
            VALUE           => 'NULL',
        );
        $users->LimitCustomField(
            SUBCLAUSE       => "$subclause-end",
            CUSTOMFIELD     => $end_cf->Id,
            COLUMN          => 'Content',
            OPERATOR        => 'IS',
            VALUE           => 'NULL',
        );

        # otherwise, "now" has to be less than start, or greater than end
        # (expressed in the query the opposite way: start has to be greater
        # than now or end has to be less than now)
        $users->LimitCustomField(
            SUBCLAUSE       => "$subclause-begin",
            CUSTOMFIELD     => $start_cf->Id,
            COLUMN          => 'Content',
            OPERATOR        => '>',
            VALUE           => $now->ISO,
            ENTRYAGGREGATOR => 'OR',
        );

        $users->LimitCustomField(
            SUBCLAUSE       => "$subclause-end",
            CUSTOMFIELD     => $end_cf->Id,
            COLUMN          => 'Content',
            OPERATOR        => '<',
            VALUE           => $now->ISO,
            ENTRYAGGREGATOR => 'OR',
        );
    }
    else {
        die "Unable to filter ExcludedDates; no 'except_between' provided.";
    }
}

1;

