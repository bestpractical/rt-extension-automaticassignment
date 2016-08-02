package RT::Extension::AutomaticAssignment::Filter::BusinessHours;
use strict;
use warnings;
use base 'RT::Extension::AutomaticAssignment::Filter';
use Business::Hours;

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

sub _IsTimeWithinBusinessHours {
    my $class  = shift;
    my $time   = shift;
    my $config = shift;
    my $tz     = shift || $RT::Timezone;

    # closely modeled off of RT::SLA

    my $res = 0;

    my $ok = eval {
        local $ENV{'TZ'} = $ENV{'TZ'};

        if ($tz && $tz ne ($ENV{'TZ'}||'') ) {
            $ENV{'TZ'} = $tz;
            require POSIX; POSIX::tzset();
        }

        my $hours = Business::Hours->new;
        $hours->business_hours(%$config);

        $res = ($hours->first_after($time) == $time);

        1;
    };

    POSIX::tzset() if $tz && $tz ne ($ENV{'TZ'}||'');
    die $@ unless $ok;

    return $res;
}

sub FiltersUsersArray {
    return 1;
}

sub FilterOwnersForTicket {
    my $class  = shift;
    my $ticket = shift;
    my $users  = shift;
    my $config = shift;

    my $now = time;

    if ($config->{user_cf}) {
        $class->_UserCF($config->{user_cf}); # validate user CF exists

        my @eligible;
        for my $user (@$users) {
            my $schedule = $user->FirstCustomFieldValue($config->{user_cf});
            if (!$schedule) {
                RT->Logger->debug("No value for user CF '$config->{user_cf}' for user " . $user->Name . "; skipping from BusinessHours automatic assignment");
                next;
            }

            my $args = $RT::ServiceBusinessHours{$schedule};
            if (!$args) {
                die "No ServiceBusinessHours config defined for schedule named '$schedule' for user " . $user->Name;
            }

            my $tz = $config->{user_tz} ? $user->Timezone : $RT::Timezone;

            push @eligible, $user
                if $class->_IsTimeWithinBusinessHours($now, $args, $tz);
        }
        return \@eligible;
    }
    else {
        die "Unable to filter BusinessHours; no 'user_cf' provided.";
    }
}

1;

