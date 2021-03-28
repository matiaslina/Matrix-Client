use JSON::Fast;
use Matrix::Client::Common;
use Matrix::Client::Requester;
use Matrix::Client::Response;

unit class Matrix::Client::Room does Matrix::Client::Requester;

has $!name;
has $.id is required;

submethod TWEAK {
    $!url-prefix = "/rooms/$!id";
}

method !get-name() {
    CATCH {
        when X::Matrix::Response {
            .code ~~ /M_NOT_FOUND/
            ?? ($!name = '')
            !! fail
        }
        default { fail }
    }
    my $data = $.state('m.room.name');
    $!name = $data<name>;
}

method name(--> Str) {
    self!get-name;
    $!name
}

method fallback-name(--> Str) {
    my @members = $.joined-members.kv.map(
        -> $k, %v {
            %v<display_name> // $k
        }
    );

    $!name = do given @members.elems {
        when 1 { @members.first }
        when 2 { @members[0] ~ " and " ~ @members[1] }
        when * > 2 { @members.first ~ " and {@members.elems - 1} others" }
        default { "Empty room" }
    };
}

#| GET - /_matrix/client/r0/rooms/{roomId}/aliases
method aliases(--> List) {
    my %data = from-json($.get('/aliases').content);
    %data<aliases>.List
}

# Events

## Getting events for a room

#| GET - /_matrix/client/r0/rooms/{roomId}/event/{eventId}
method event(Str $event-id --> Matrix::Client::Response::RoomEvent) {
    my %data = from-json($.get("/event/$event-id").content);
    Matrix::Client::Response::RoomEvent.new(|%data)
}

#| GET - /_matrix/client/r0/rooms/{roomId}/state
multi method state(--> Seq) {
    my $data = from-json($.get('/state').content);

    gather for $data.List -> $event {
        take Matrix::Client::Response::StateEvent.new(:room-id($.id), |$event)
    }
}

#| GET - /_matrix/client/r0/rooms/{roomId}/state/{eventType}/{stateKey}
multi method state(Str $event-type, Str $state-key = "") {
    from-json($.get("/state/$event-type/$state-key").content)
}

#| GET - /_matrix/client/r0/rooms/{roomId}/joined_members
method joined-members {
    my %data = from-json($.get("/joined_members").content);
    %data<joined>
}

#| GET - /_matrix/client/r0/rooms/{roomId}/messages
method messages(
    Str:D :$from!, Str :$to,
    Str :$dir where * eq 'f'|'b' = 'f',
    Int :$limit = 10, :%filter,
    --> Matrix::Client::Response::Messages
) {
    my $res = $.get(
        "/messages", :$from, :$to, :$dir, :$limit, :%filter
    );
    my $data = from-json($res.content);


    my @messages = $data<chunk>.map(-> $ev {
        Matrix::Client::Response::RoomEvent.new(|$ev)
    });

    Matrix::Client::Response::Messages.new(
        start => $data<start>,
        end => $data<end>,
        messages => @messages
    )
}

#| GET - /_matrix/client/r0/rooms/{roomId}/members
method members(:$at, Str :$membership, Str :$not-membership --> Seq) {
    my %query;

    %query<at> = $at with $at;
    %query<membership> = $membership with $membership;
    %query<not_membership> = $not-membership with $not-membership;

    my %data = from-json($.get('/members', |%query).content);

    gather for %data<chunk>.List -> $ev {
        take Matrix::Client::Response::MemberEvent.new(|$ev)
    }
}

##  Sending events to a room

#| PUT - /_matrix/client/r0/rooms/{roomId}/send/{eventType}/{txnId}
method send(Str $body!, Str :$type? = "m.text") {
    $Matrix::Client::Common::TXN-ID++;
    my $res = $.put(
        "/send/m.room.message/{$Matrix::Client::Common::TXN-ID}",
        msgtype => $type, body => $body
    );

    from-json($res.content)<event_id>
}

#| PUT - /_matrix/client/r0/rooms/{roomId}/state/{eventType}/{stateKey}
method send-state(Str:D $event-type, :$state-key = "", *%args --> Str) {
    my $res = $.put(
        "/state/$event-type/$state-key",
        |%args
    );
    from-json($res.content)<event_id>
}

#| POST - /_matrix/client/r0/rooms/{roomId}/read_markers
method read-marker(Str:D $fully-read, Str $read?) {
    my %data = %(
        "m.fully_read" => $fully-read
    );

    %data<m.read> = $read with $read;

    $.post('/read_markers', |%data);
}

#| PUT - /_matrix/client/r0/rooms/{roomId}/typing/{userId}
method typing(Bool $typing, Str :$user-id!, Int :$timeout) {
    my %data = :$typing;

    %data<timeout> = $timeout with $timeout;
    $.put(
        "/typing/{$user-id}", |%data
    );
}

# Room membership!

## Joining rooms

#| POST - /_matrix/client/r0/rooms/{roomId}/invite
method invite(Str $user-id) {
    $.post('/invite', :$user-id)
}

#| POST - /_matrix/client/r0/rooms/{roomId}/join
method join {
    $.post('/join')
}

## Leaving rooms

#| POST - /_matrix/client/r0/rooms/{roomId}/leave
method leave {
    $.post('/leave')
}

#| POST - /_matrix/client/r0/rooms/{roomId}/forget
method forget {
    $.post('/forget')
}

#| POST - /_matrix/client/r0/rooms/{roomId}/kick
method kick(Str $user-id, Str $reason = "") {
    $.post('/kick', :$user-id, :$reason)
}

## Banning users

#| POST - /_matrix/client/r0/rooms/{roomId}/ban
method ban(Str $user-id, $reason = "") {
    $.post('/ban', :$user-id, :$reason)
}

#| POST - /_matrix/client/r0/rooms/{roomId}/unban
method unban(Str $user-id) {
    $.post('/unban', :$user-id)
}

method Str(--> Str) {
    "Room<id: {self.id}>"
}
