use HTTP::Request::Common;
use URI::Encode;
use JSON::Tiny;
use Matrix::Response;
use Matrix::Client::Common;
use Matrix::Client::Room;
use Matrix::Client::Requester;

unit class Matrix::Client does Matrix::Client::Requester;

has Str $.user-id;
has Str $.device-id;
has Str $!auth-file;
has $!logged = False;
has @!rooms;
has @!users;

submethod BUILD(:$!home-server!, :$!auth-file = 'auth') {
    if $!auth-file.IO.e {
        my $data = from-json(slurp $!auth-file);
        $!access-token = $data<access_token>;
        $!user-id = $data<user_id>;
        $!device-id = $data<device_id>;
        $Matrix::Client::Common::TXN-ID = $data<txn_id> // 0;
        $!logged = True;
    }
}

method login(Str $username, Str $pass) returns Bool {
    return if $!logged;

    # Handle POST
    my $post-data = to-json {
        type => "m.login.password",
        user => $username,
        password => $pass
    };

    my $res = $.post("/login", $post-data);
    spurt $!auth-file, $res.content;

    my $data = from-json($res.content);
    $!access-token = $data<access_token>;
    $!user-id = $data<user_id>;
    $!device-id = $data<device_id>;
}

method save-auth-data() {
    my %data = 
        access_token => $!access-token,
        user_id => $.user-id,
        device_id => $.device-id,
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
    my $data = from-json $res.content;
    $!access-token = $data<access_token>;
    $.user-id = $data<user_id>;
}

# User Data

method profile(Str :$user-id?) {
    my $id = $user-id // $.user-id;
    $.get("/profile/" ~ $id)
}

method display-name(Str :$user-id?) {
    my $id = $user-id // $.user-id;
    my $res = $.get("/profile/" ~ $id ~ "/displayname");

    my $data = from-json($res.content);

    $data<displayname> // ""
}

method change-display-name(Str:D $display-name!) {
    $.put("/profile/" ~ $.user-id ~ "/displayname",
          displayname => $display-name)
}

method avatar-url(Str :$user-id?) {
    my $id = $user-id // $.user-id;
    my $res = $.get("/profile/" ~ $id ~ "/avatar_url");
    my $data = from-json($res.content);

    $data<avatar_url> // ""
}

multi method change-avatar(IO::Path $avatar) {
    my $mxc-url = $.upload($avatar.IO);
    samewith($mxc-url);
}

multi method change-avatar(Str:D $mxc-url!) {
    $.put("/profile/" ~ $.user-id ~ "/avatar_url",
          avatar_url => $mxc-url);
}

# Syncronization

multi method sync() {
    my $res = $.get("/sync", timeout => 30000);

    Matrix::Response::Sync.new($res.content)
}

multi method sync(Str :$sync-filter, Str :$since = "") {
    my $res = $.get("/sync",
        timeout => 30000,
        filter => $sync-filter,
        since => $since
    );

    Matrix::Response::Sync.new($res.content)
}

multi method sync(:$sync-filter is copy, :$since = "") {
    $.sync(sync-filter => to-json($sync-filter), since => $since)
}

# Rooms

method join-room($room-id!) {
    $.post("/join/$room-id")
}

method leave-room($room-id) {
    $.post("/rooms/$room-id/leave");
}

method rooms(Bool :$sync = False) {
    return @!rooms unless $sync;
    my $res = $.get("/sync", timeout => "30000");

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

method joined-rooms() {
    my $res = $.get('/joined_rooms');

    my $data = from-json($res.content);
    return $data<joined_rooms>.Seq.map(-> $room-id {
        Matrix::Client::Room.new(
            id => $room-id,
            home-server => $!home-server,
            access-token => $!access-token
        )
    });
}

method public-rooms() {
    $.get('/publicRooms')
}

method send(Str $room-id, Str $body, :$type? = "m.text") {
    $Matrix::Client::Common::TXN-ID++;
    $.put("/rooms/$room-id/send/m.room.message/{$Matrix::Client::Common::TXN-ID}",
          msgtype => $type, body => $body
    )
}

# Media

method upload(IO::Path $path, Str $filename?) {
    my $buf = slurp $path, :bin;
    my $fn = $filename ?? $filename !! $path.basename;
    my $res = $.post-bin("/upload", $buf,
        content-type => "image/png",
        filename => $fn,
    );
    my $data = from-json($res.content);
    $data<content_uri> // "";
}
