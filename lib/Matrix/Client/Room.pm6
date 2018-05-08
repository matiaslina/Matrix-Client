use JSON::Tiny;
use Matrix::Client::Common;
use Matrix::Client::Requester;

unit class Matrix::Client::Room does Matrix::Client::Requester;

has $!name;
has $.id;

multi submethod BUILD(Str :$!id!, :$!home-server!, :$!access-token!, :$json?) {
    $!url-prefix = "/rooms/$!id";
    
    if so $json {
        my @events = $json<state><events>.clone;
        for @events -> $ev {
            if $ev<type> eq "m.room.name" {
                $!name = $ev<content><name>;
            }
        }
    }
}

method !get-name() {
    my $res = $.get('/state/m.room.name');
    if $res.is-success {
        $!name = from-json($res.content)<name>
    } else {
        warn "Error {$res.status-line}, content {$res.content}";
    }
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
    $.put("/send/m.room.message/{$Matrix::Client::Common::TXN-ID}", msgtype => $type, body => $body)
}

method leave() {
    $.post('/leave')
}

method gist(--> Str) {
    "Room<name: {self.name()}, id: {self.id}>"
}

method Str(--> Str) {
    "Room<name: {self.name()}, id: {self.id}>"
}
