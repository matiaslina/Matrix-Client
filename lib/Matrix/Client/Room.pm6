use JSON::Tiny;
use Matrix::Client::Common;
use Matrix::Client::Requester;

unit class Matrix::Client::Room does Matrix::Client::Requester;

has $.name is rw;
has $.id is rw;
has $!prev-batch;

submethod BUILD(Str :$!id!, :$json!, :$!home-server!, :$!access-token!) {
    $!url-prefix = "/rooms/$!id";
    $!prev-batch = $json<timeline><prev_batch>;
    
    if so $json {
        my @events = $json<state><events>.clone;
        for @events -> $ev {
            if $ev<type> eq "m.room.name" {
                $!name = $ev<content><name>;
            }
        }
    }

    # FIXME: Should be a 1:1 conversation
    unless $!name {
        $!name = "Unknown";
    }
}

method messages() {
    my $res = $.get("/messages");
    my $data = from-json($res.content);

    return $data<chunk>.clone;
}

method send(Str $body!, Str :$type? = "m.text") {
    $Matrix::Client::Common::TXN-ID++;
    $.put("/send/m.room.message/{$Matrix::Client::Common::TXN-ID}", msgtype => $type, body => $body)
}

method gist(--> Str) {
    "Room<name: $.name, id: $.id>"
}
