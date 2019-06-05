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

#| POST - /_matrix/client/r0/login
multi method login(Str $username, Str $password) {
    $.login(:$username, :$password);
}

#| POST - /_matrix/client/r0/login
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

#| POST - /_matrix/client/r0/logout
method logout() {
    $.post("/logout")
}

#| POST - /_matrix/client/r0/register
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

#| GET - /_matrix/client/r0/profile/{userId}
method profile(Str :$user-id?) {
    my $id = $user-id // $.whoami;
    from-json($.get("/profile/" ~ $id).content);
}

#| GET - /_matrix/client/r0/profile/{userId}/displayname
method display-name(Str :$user-id?) {
    my $id = $user-id // $.whoami;
    my $res = $.get("/profile/" ~ $id ~ "/displayname");

    my $data = from-json($res.content);

    $data<displayname> // ""
}

#| PUT - /_matrix/client/r0/profile/{userId}/displayname
method change-display-name(Str:D $display-name!) {
    so $.put("/profile/" ~ $.whoami ~ "/displayname",
          displayname => $display-name)
}

#| GET - /_matrix/client/r0/profile/{userId}/avatar_url
method avatar-url(Str :$user-id?) {
    my $id = $user-id // $.whoami;
    my $res = $.get("/profile/" ~ $id ~ "/avatar_url");
    my $data = from-json($res.content);

    $data<avatar_url> // ""
}

#| PUT - /_matrix/client/r0/profile/{userId}/avatar_url
multi method change-avatar(IO::Path $avatar) {
    my $mxc-url = $.upload($avatar.IO);
    samewith($mxc-url);
}

#| PUT - /_matrix/client/r0/profile/{userId}/avatar_url
multi method change-avatar(Str:D $mxc-url!) {
    $.put("/profile/" ~ $.whoami ~ "/avatar_url",
          avatar_url => $mxc-url);
}

#| GET - /_matrix/client/r0/account/whoami
method whoami {
    unless $!user-id {
        my $res = $.get('/account/whoami');
        my $data = from-json($res.content);
        $!user-id = $data<user_id>;
    }

    $!user-id
}

#| GET - /_matrix/client/r0/presence/{userId}/status
method presence(Matrix::Client:D: $user-id? --> Matrix::Response::Presence) {
    my $id = $user-id // $.whoami;
    my $data = from-json($.get("/presence/$id/status").content);
    Matrix::Response::Presence.new(|$data)
}

#| PUT - /_matrix/client/r0/presence/{userId}/status
method set-presence(Matrix::Client:D: Str $presence, Str :$status-message = "") {
    $.put("/presence/$.whoami/status",
          :$presence, :status_msg($status-message));
}

#| PUT - /_matrix/client/r0/user/{userId}/rooms/{roomId}/tags/{tag}
multi method tags(Str $room-id, Str:D $tag, $order) {
    my $id = $.whoami;
    from-json($.put("/user/$id/rooms/$room-id/tags/$tag", :$order).content)
}

#| GET - /_matrix/client/r0/user/{userId}/rooms/{roomId}/tags
multi method tags(Str $room-id) {
    my $id = $.whoami;
    Matrix::Response::Tag.new(from-json($.get("/user/$id/rooms/$room-id/tags").content))
}

#| DELETE - /_matrix/client/r0/user/{userId}/rooms/{roomId}/tags/{tag}
method remove-tag(Str $room-id, Str:D $tag) {
    my $id = $.whoami;
    $.delete("/user/$id/rooms/$room-id/tags/$tag")
}

# Syncronization

#| GET - /_matrix/client/r0/sync
multi method sync(Hash :$sync-filter is copy, :$since = "") {
    $.sync(sync-filter => to-json($sync-filter), since => $since)
}

#| GET - /_matrix/client/r0/sync
multi method sync(Str:D :$sync-filter, Str :$since = "") {
    my $res = $.get("/sync",
        timeout => 30000,
        :$sync-filter,
        :$since
    );

    Matrix::Response::Sync.new($res.content)
}

#| GET - /_matrix/client/r0/sync
multi method sync(:$since = "") {
    my $res = $.get("/sync", timeout => 30000, since => $since);
    Matrix::Response::Sync.new($res.content)
}

# Rooms

#| POST - /_matrix/client/r0/createRoom
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

#| POST - /_matrix/client/r0/join/{roomIdOrAlias}
method join-room($room-id!) {
    $.post("/join/$room-id")
}

#| POST - /_matrix/client/r0/rooms/{roomId}/leave
method leave-room($room-id) {
    $.post("/rooms/$room-id/leave");
}

#| GET - /_matrix/client/r0/joined_rooms
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

#| GET - /_matrix/client/r0/publicRooms
method public-rooms() {
    $.get('/publicRooms')
}

#| PUT - /_matrix/client/r0/rooms/{roomId}/send/{eventType}/{txnId}
method send(Str $room-id, Str $body, :$type? = "m.text") {
    $Matrix::Client::Common::TXN-ID++;
    my $res = $.put(
        "/rooms/$room-id/send/m.room.message/{$Matrix::Client::Common::TXN-ID}",
        msgtype => $type, body => $body
    );

    from-json($res.content)<event_id>
}

#| GET - /_matrix/client/r0/directory/room/{roomAlias}
method get-room-id($room-alias) {
    my $res = $.get("/directory/room/$room-alias");

    from-json($res.content)<room_id>
}

#| PUT - /_matrix/client/r0/directory/room/{roomAlias}
method add-room-alias($room-id, $room-alias) {
    $.put("/directory/room/$room-alias",
          room_id => $room-id);
}

#| DELETE - /_matrix/client/r0/directory/room/{roomAlias}
method remove-room-alias($room-alias) {
    $.delete("/directory/room/$room-alias");
}

# Media

#| POST - /_matrix/media/r0/upload
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
