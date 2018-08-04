use JSON::Tiny;
use Matrix::Client::Common;
use Matrix::Client::Requester;

unit class Matrix::Client::Room does Matrix::Client::Requester;

has $!name;
has $.id;

submethod TWEAK {
    $!url-prefix = "/rooms/$!id";
}

method !get-name() {
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

method leave() {
    $.post('/leave')
}

method gist(--> Str) {
    "Room<id: {self.id}>"
}

method Str(--> Str) {
    "Room<id: {self.id}>"
}
