use HTTP::Request::Common;
use URI::Encode;
use JSON::Tiny;
use Matrix::Client::Common;
use Matrix::Client::Room;
use Matrix::Client::Requester;

unit class Matrix::Client does Matrix::Client::Requester;

has Str $!user-id;
has Str $!device-id;
has Str $!auth-file;
has $!logged = False;
has @!rooms;
has @!users;

submethod BUILD(:$!home-server, :$!auth-file = 'auth') {
    if $!auth-file.IO.e {
        my $data = from-json(slurp $!auth-file);
        $!access-token = $data<access_token>;
        $!user-id = $data<user_id>;
        $!device-id = $data<device_id>;
        $Matrix::Client::Common::TXN-ID = $data<txn_id> // 0;
        $!logged = True;
    }
}

method user-id() {
    $!user-id
}

method device-id() {
    $!device-id
}

method login(Str $username, Str $pass) returns Bool {
    return True if $!logged;

    # Handle POST
    my $data = to-json {
        type => "m.login.password",
        user => $username,
        password => $pass
    };

    my $res = $.post("/login", $data);
    if $res.is-success {
        spurt $!auth-file, $res.content;
        my $data = from-json($res.content);
        $!access-token = $data<access_token>;
        $!user-id = $data<user_id>;
        $!device-id = $data<device_id>;
        True
    } else {
        False
    }
}

method save-auth-data() {
    my %data = 
        access_token => $!access-token,
        user_id => $!user-id,
        device_id => $!device-id,
        txn_id => $Matrix::Client::Common::TXN-ID;

    spurt $!auth-file, to-json(%data);
}

method logout() {
    unlink $!auth-file;
    $.post("/logout")
}

method register($username, $password, Bool :$bind-email? = False) {
    my $res = $.post("/register",
                     username => $username, password => $password,
                     bind_email => $bind-email,
                     auth => {
                            type => "m.login.dummy"
                    });
    if $res.is-success {
        my $data = from-json $res.content;
        $!access-token = $data<access_token>;
        $.user-id = $data<user_id>;
    } else {
        die "Error with the homeserver: " ~ $res.content;
    }
}

method check-res($res) {
    if $res.is-success {
        True
    } else {
        warn $res.status-line;
        warn $res.content;
        False
    }
}

# User Data

method profile(Str :$user-id?) {
    my $id = $user-id // $!user-id;
    my $res = $.get("/profile/" ~ $id);
    $.check-res($res);
    $res
}

method display-name(Str :$user-id?) {
    my $id = $user-id // $!user-id;
    my $res = $.get("/profile/" ~ $id ~ "/displayname");
    $.check-res($res);

    my $data = from-json($res.content);

    $data<displayname> // ""
}

method change-display-name(Str:D $display-name!) {
    my $res = $.put("/profile/" ~ $!user-id ~ "/displayname",
                    displayname => $display-name);
    return $.check-res($res);
}

method avatar-url(Str :$user-id?) {
    my $id = $user-id // $!user-id;
    my $res = $.get("/profile/" ~ $id ~ "/avatar_url");
    $.check-res($res);
    my $data = from-json($res.content);

    $data<avatar_url> // ""
}

method change-avatar(Str:D $avatar!, Bool :$upload) {
    my $mxc-url;
    if so $upload {
        $mxc-url = $.upload($avatar);
    } else {
        $mxc-url = $avatar;
    }

    my $res = $.put("/profile/" ~ $!user-id ~ "/avatar_url",
                    avatar_url => $mxc-url);
    return $.check-res($res);
}

# Syncronization

multi method sync() {
    my $res = $.get("/sync",
        timeout => 30000
    );

    $.check-res($res);
    $res
}

multi method sync(Str :$sync-filter, Str :$since = "") {
    my $res = $.get("/sync",
        timeout => 30000,
        filter => $sync-filter,
        since => $since
    );

    $.check-res($res);
    $res
}

multi method sync(:$sync-filter is copy, :$since = "") {
    $.sync(sync-filter => to-json($sync-filter), since => $since)
}

# Rooms

method join-room($room-id!) {
    $.post("/join/" ~ $room-id)
}

method rooms(Bool :$sync = False) {
    return @!rooms unless $sync;
    my $res = $.get("/sync", timeout => "30000");

    return () unless $res.is-success;
    @!rooms = ();
    my $data = from-json($res.content);
    for $data<rooms><join>.kv -> $id, $json {
        @!rooms.push(Matrix::Client::Room.new(
            id => $id,
            json => $json,
            home-server => $!home-server,
            access-token => $!access-token
        ));
    }

    @!rooms
}

method send(Str $room-id, Str $body, :$type? = "m.text") {
    $Matrix::Client::Common::TXN-ID++;
    $.put("/rooms/$room-id/send/m.room.message/{$Matrix::Client::Common::TXN-ID}", msgtype => $type, body => $body)
}

# Media

method upload(Str $path where *.IO.f) {
    my $buf = slurp $path, :bin;
    my $res = $.post-bin("/upload", $buf, content-type => "image/png");
    $.check-res($res);
    my $data = from-json($res.content);
    $data<content_uri> // "";
}
