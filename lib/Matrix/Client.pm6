use HTTP::Request::Common;
use URI::Encode;
use JSON::Tiny;
use Matrix::Response;
use Matrix::Client::Common;
use Matrix::Client::Room;
use Matrix::Client::Requester;

unit class Matrix::Client does Matrix::Client::Requester;

has Str $.device-id;
has Str $!user-id;
has @!rooms;
has @!users;

submethod TWEAK {
    $Matrix::Client::Common::TXN-ID = now.Int;
}


multi method login(Str $username, Str $password) {
    $.login(:$username, :$password);
}

multi method login(Str :$username, Str :$password) {
    my $post-data = {
        type => "m.login.password",
        user => $username,
        password => $password
    };

    if $!device-id {
        $post-data<device_id> = $!device-id;
    }

    my $res = $.post("/login", to-json($post-data));
    my $data = from-json($res.content);

    $!access-token = $data<access_token>;
    $!user-id = $data<user_id>;
    $!device-id = $data<device_id>;
}

method logout() {
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
    $!user-id = $data<user_id>;
}

# User Data

method profile(Str :$user-id?) {
    my $id = $user-id // $.whoami;
    from-json($.get("/profile/" ~ $id).content);
}

method display-name(Str :$user-id?) {
    my $id = $user-id // $.whoami;
    my $res = $.get("/profile/" ~ $id ~ "/displayname");

    my $data = from-json($res.content);

    $data<displayname> // ""
}

method change-display-name(Str:D $display-name!) {
    so $.put("/profile/" ~ $.whoami ~ "/displayname",
          displayname => $display-name)
}

method avatar-url(Str :$user-id?) {
    my $id = $user-id // $.whoami;
    my $res = $.get("/profile/" ~ $id ~ "/avatar_url");
    my $data = from-json($res.content);

    $data<avatar_url> // ""
}

multi method change-avatar(IO::Path $avatar) {
    my $mxc-url = $.upload($avatar.IO);
    samewith($mxc-url);
}

multi method change-avatar(Str:D $mxc-url!) {
    $.put("/profile/" ~ $.whoami ~ "/avatar_url",
          avatar_url => $mxc-url);
}

method whoami {
    unless $!user-id {
        my $res = $.get('/account/whoami');
        my $data = from-json($res.content);
        $!user-id = $data<user_id>;
    }

    $!user-id
}

method presence(Matrix::Client:D: $user-id? --> Matrix::Response::Presence) {
    my $id = $user-id // $.whoami;
    my $data = from-json($.get("/presence/$id/status").content);
    Matrix::Response::Presence.new(|$data)
}

method set-presence(Matrix::Client:D: Str $presence, Str :$status-message = "") {
    $.put("/presence/$.whoami/status",
          :$presence, :status_msg($status-message));
}

# Syncronization

multi method sync(Hash :$sync-filter is copy, :$since = "") {
    $.sync(sync-filter => to-json($sync-filter), since => $since)
}

multi method sync(Str:D :$sync-filter, Str :$since = "") {
    my $res = $.get("/sync",
        timeout => 30000,
        :$sync-filter,
        :$since
    );

    Matrix::Response::Sync.new($res.content)
}

multi method sync(:$since = "") {
    my $res = $.get("/sync", timeout => 30000, since => $since);
    Matrix::Response::Sync.new($res.content)
}

# Rooms

method create-room(
    Bool :$public = False,
    *%args --> Matrix::Client::Room
) {
    my %params;

    for %args.kv -> $key, $value {
        %params{$key.subst('-', '_')} = $value;
    }

    if 'visibility' ~~ %params {
        %params<visibility> = $public;
    }

    my $res = from-json($.post('/createRoom', |%params).content);

    Matrix::Client::Room.new(
        id => $res<room_id>,
        access-token => self.access-token,
        home-server => self.home-server
    )
}

method join-room($room-id!) {
    $.post("/join/$room-id")
}

method leave-room($room-id) {
    $.post("/rooms/$room-id/leave");
}

method joined-rooms(--> Seq) {
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
    my $res = $.put(
        "/rooms/$room-id/send/m.room.message/{$Matrix::Client::Common::TXN-ID}",
        msgtype => $type, body => $body
    );

    from-json($res.content)<event_id>
}

method get-room-id($room-alias) {
    my $res = $.get("/directory/room/$room-alias");

    from-json($res.content)<room_id>
}

method add-room-alias($room-id, $room-alias) {
    $.put("/directory/room/$room-alias",
          room_id => $room-id);
}

method remove-room-alias($room-alias) {
    $.delete("/directory/room/$room-alias");
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

# Misc

method run(Int :$sleep = 10, :$sync-filter? --> Supply) {
    my $s = Supplier.new;
    my $supply = $s.Supply;
    my $since = "";

    start {
        loop {
            my $sync = $.sync(:$since, :$sync-filter);
            $since = $sync.next-batch;

            for $sync.invited-rooms -> $info {
                $s.emit($info);
            }

            for $sync.joined-rooms -> $room {
                for $room.timeline.events -> $event {
                    $s.emit($event)
                }
            }
            sleep $sleep;
        }
    }
    $supply
}
