Set($AutomaticAssignmentFilters, [qw(
    ExcludedDates
    MemberOfGroup
    MemberOfRole
    WorkSchedule
)]) unless $AutomaticAssignmentFilters;

Set($AutomaticAssignmentChoosers, [qw(
    Random
    RoundRobin
    TicketStatus
    TimeLeft
)]) unless $AutomaticAssignmentChoosers;

1;

