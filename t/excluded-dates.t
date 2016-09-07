use strict;
use warnings;

use RT::Extension::AutomaticAssignment::Test tests => undef;
use Test::MockTime 'set_fixed_time';

my $queue = RT::Queue->new(RT->SystemUser);
$queue->Load('General');
ok($queue->Id, 'loaded General queue');

my $begin = RT::CustomField->new(RT->SystemUser);
my ($ok, $msg) = $begin->Create(
    Name       => 'Vacation Begin',
    LookupType => RT::User->CustomFieldLookupType,
    Type       => 'DateTime',
    MaxValues  => 1,
);
ok($ok, "created Vacation Begin CF");

($ok, $msg) = $begin->AddToObject(RT::User->new(RT->SystemUser));
ok($ok, "made Vacation Begin global");

my $end = RT::CustomField->new(RT->SystemUser);
($ok, $msg) = $end->Create(
    Name       => 'Vacation End',
    LookupType => RT::User->CustomFieldLookupType,
    Type       => 'DateTime',
    MaxValues  => 1,
);
ok($ok, "created Vacation End CF");

($ok, $msg) = $end->AddToObject(RT::User->new(RT->SystemUser));
ok($ok, "made Vacation End global");

my $assignees = RT::Group->new(RT->SystemUser);
$assignees->CreateUserDefinedGroup(Name => 'Assignees');
$assignees->PrincipalObj->GrantRight(Right => 'OwnTicket', Object => $queue);

($ok, $msg) = RT::Extension::AutomaticAssignment->_SetConfigForQueue(
    $queue,
    [
        { ClassName => 'ExcludedDates', begin => $begin->Id, end => $end->Id },
        { ClassName => 'MemberOfGroup', group => $assignees->Id },
    ],
    { ClassName => 'Random' },
);
ok($ok, "set AutomaticAssignment config");

sub add_user {
    my $name = shift;
    my $begin_vacation = shift;
    my $end_vacation = shift;

    my $user = RT::User->new(RT->SystemUser);
    my ($ok, $msg) = $user->Create(
        Name => $name,
    );
    ok($ok, "created user $name");

    ($ok, $msg) = $assignees->AddMember($user->Id);
    ok($ok, "added user $name to Assignees group");

    if ($begin_vacation) {
        ($ok, $msg) = $user->AddCustomFieldValue(
            Field => $begin->Id,
            Value => $begin_vacation,
        );
        ok($ok, "added Vacation Begin $begin_vacation: $msg");
    }

    if ($end_vacation) {
        ($ok, $msg) = $user->AddCustomFieldValue(
            Field => $end->Id,
            Value => $end_vacation,
        );
        ok($ok, "added Vacation End $end_vacation: $msg");
    }

    return $user;
}

sub eligible_ownerlist_is {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $input_time = shift;
    my $expected = shift;
    my $msg = shift;

    my $epoch = do {
        my $date = RT::Date->new(RT->SystemUser);
        $date->Set(Format => 'unknown', Value => $input_time);
        $date->Unix;
    };

    set_fixed_time($epoch);

    my $ticket = RT::Ticket->new(RT->SystemUser);
    $ticket->Create(Queue => $queue->Id);
    ok($ticket->Id, 'created ticket');

    my $got = RT::Extension::AutomaticAssignment->_EligibleOwnersForTicket(
        $ticket,
        undef,
        { time => $epoch },
    );

    is_deeply(
        [ sort map { $_->Name } @$got ],
        [ sort @$expected ],
        $msg,
    );
}

eligible_ownerlist_is '2016-09-07 13:20:00' => [qw//], 'no assignees yet';

add_user 'NoVacation', undef, undef;
eligible_ownerlist_is '2016-09-07 13:20:00' => [qw/NoVacation/];

add_user 'AfterVacation', '2015-01-01 00:00:00', '2015-01-10 00:00:00';
eligible_ownerlist_is '2016-09-07 13:20:00' => [qw/NoVacation AfterVacation/];

done_testing;

