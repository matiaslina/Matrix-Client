use JSON::Tiny;
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

method name() {
    unless $!name.so { self!get-name() }
    $!name
}

method messages() {
    my $res = $.get("/messages");
    my $data = from-json($res.content);

    return $data<chunk>.clone;
}

method send(Str $body!, Str :$type? = "m.text") {
    $Matrix::Client::Common::TXN-ID++;
    my $res = $.put(
        "/send/m.room.message/{$Matrix::Client::Common::TXN-ID}",
        msgtype => $type, body => $body
    );

    from-json($res.content)<event_id>
}

multi method state(--> Seq) {
    my $data = from-json($.get('/state').content);

    gather for $data.List -> $event {
        take Matrix::Response::StateEvent.new(:room-id($.id), |$event)
    }
}

multi method state(Str $event-type) {
    from-json($.get("/state/$event-type").content)
}

method send-state(Str:D $event-type, :$state-key = "", *%args --> Str) {
    my $res = $.put(
        "/state/$event-type/$state-key",
        |%args
    );
    from-json($res.content)<event_id>
}


method leave() {
    $.post('/leave')
}

method Str(--> Str) {
    "Room<id: {self.id}>"
}
