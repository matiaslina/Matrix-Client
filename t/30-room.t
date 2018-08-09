use lib 'lib';
use Test;
use Matrix::Client;
plan 10;

unless %*ENV<MATRIX_CLIENT_TEST_SERVER> {
    skip-rest 'No test server setted';
    exit;
}

my $home-server = %*ENV<MATRIX_CLIENT_TEST_SERVER>;
my $username = %*ENV<MATRIX_CLIENT_USERNAME>;
my $password = %*ENV<MATRIX_CLIENT_PASSWORD>;
my $device-id = %*ENV<MATRIX_CLIENT_DEVICE_ID>;
my $public-room-id = %*ENV<MATRIX_CLIENT_PUBLIC_ROOM> // '!cYTYddgfJTLTzdiDBP:localhost';
my Matrix::Client $client .= new(:$home-server);

$client.login(:$username, :$password);

my $room-alias = 'Room' ~ (^10).map({('a'…'z').pick}).join;
my $main-room;

lives-ok {
    $main-room = $client.create-room(
        :public,
        :preset<public_chat>,
        :room_alias_name($room-alias),
        :name("The Grand Duke Pub"),
        :topic("All about happy hour"),
        :creation_content({
            "m.federate" => False
        })
    );
}, 'Can create room';

isa-ok $main-room, Matrix::Client::Room;

my $room-id = $main-room.id;

lives-ok {
    $main-room.leave;
}, 'Can leave room';

lives-ok {
    $main-room.join;
}, 'Can join a room';

lives-ok {
    $client.join-room($public-room-id)
}, 'Can join public room';

my @rooms = $client.joined-rooms;
my $public-room = @rooms.first(-> $room { $room.id eq $public-room-id });

isa-ok $public-room, Matrix::Client::Room;
isa-ok $public-room.send('hi'), Str;

subtest 'states' => {
    plan 2;
    isa-ok $main-room.state(), Seq;
    my @states = $main-room.state();
    isa-ok @states.first(), Matrix::Response::StateEvent;
};

subtest 'creation' => {
    plan 3;
    my $new-room = Matrix::Client::Room.new(
        :id($public-room.id),
        :$home-server,
        :access-token($client.access-token)
    );

    ok $new-room, 'Can .new a room with the id of the public room';
    isa-ok $new-room, Matrix::Client::Room;
    is $new-room.id, $public-room.id, 'The id is the same as the public room';
};

subtest 'name' => {
    plan 4;

    my $name = "Name room test";
    my $test-room = $client.create-room:
        :creation_content({
            "m.federate" => False
        });

    is $test-room.name(), '';

    lives-ok {
        $test-room.send-state('m.room.name', :name($name))
    }, 'Can change name to an unnamed room';

    lives-ok {
        $test-room.name()
    }, '.name with a name set dont die';

    is $test-room.name, $name, 'The name is set correctly';

    $test-room.leave;
};
