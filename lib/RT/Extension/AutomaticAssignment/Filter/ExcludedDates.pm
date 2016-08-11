package RT::Extension::AutomaticAssignment::Filter::ExcludedDates;
use strict;
use warnings;
use base 'RT::Extension::AutomaticAssignment::Filter';

sub _UserCF {
    my $class = shift;
    my $id    = shift;

    my $cf = RT::CustomField->new(RT->SystemUser);
    $cf->LoadByCols(
        id         => $id,
        LookupType => RT::User->CustomFieldLookupType,
    );
    if (!$cf->Id) {
        die "Unable to load User Custom Field '$id'";
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

    if ($config->{begin} && $config->{end}) {
        my $begin_cf = $class->_UserCF($config->{begin});
        my $end_cf = $class->_UserCF($config->{end});

        my $subclause = $begin_cf->Id . '-' . $end_cf->Id;

        # allow users for whom begin/end is null
        $users->LimitCustomField(
            SUBCLAUSE       => "$subclause-begin",
            CUSTOMFIELD     => $begin_cf->Id,
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

        # otherwise, "now" has to be less than begin, or greater than end
        # (expressed in the query the opposite way: begin has to be greater
        # than now or end has to be less than now)
        $users->LimitCustomField(
            SUBCLAUSE       => "$subclause-begin",
            CUSTOMFIELD     => $begin_cf->Id,
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
        die "Unable to filter ExcludedDates; both 'begin' and 'end' must be provided.";
    }
}

sub Description { "Excluded Dates" }

sub CanonicalizeConfig {
    my $class = shift;
    my $input = shift;

    my $begin = $input->{begin} || 0;
    $begin =~ s/[^0-9]//g; # allow only numeric id

    my $end = $input->{end} || 0;
    $end =~ s/[^0-9]//g; # allow only numeric id

    return { begin => $begin, end => $end };
}

1;

