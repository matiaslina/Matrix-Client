use JSON::Fast;
use Matrix::Client::Common;
use Matrix::Client::Requester;
use Matrix::Response;

unit class Matrix::Client::Room does Matrix::Client::Requester;

has $!name;
has $.id;

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

#| GET - /_matrix/client/r0/rooms/{roomId}/joined_members
method joined-members {
    my %data = from-json($.get("/joined_members").content);
    %data<joined>
}

method name {
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

#| GET - /_matrix/client/r0/rooms/{roomId}/messages
method messages() {
    my $res = $.get("/messages");
    my $data = from-json($res.content);

    return $data<chunk>.clone;
}

#| PUT - /_matrix/client/r0/rooms/{roomId}/send/{eventType}/{txnId}
method send(Str $body!, Str :$type? = "m.text") {
    $Matrix::Client::Common::TXN-ID++;
    my $res = $.put(
        "/send/m.room.message/{$Matrix::Client::Common::TXN-ID}",
        msgtype => $type, body => $body
    );

    from-json($res.content)<event_id>
}

#| GET - /_matrix/client/r0/rooms/{roomId}/state
multi method state(--> Seq) {
    my $data = from-json($.get('/state').content);

    gather for $data.List -> $event {
        take Matrix::Response::StateEvent.new(:room-id($.id), |$event)
    }
}

#| GET - /_matrix/client/r0/rooms/{roomId}/state/{eventType}
multi method state(Str $event-type) {
    from-json($.get("/state/$event-type").content)
}

#| PUT - /_matrix/client/r0/rooms/{roomId}/state/{eventType}/{stateKey}
method send-state(Str:D $event-type, :$state-key = "", *%args --> Str) {
    my $res = $.put(
        "/state/$event-type/$state-key",
        |%args
    );
    from-json($res.content)<event_id>
}

#| POST - /_matrix/client/r0/rooms/{roomId}/leave
method leave() {
    $.post('/leave')
}

method Str(--> Str) {
    "Room<id: {self.id}>"
}
