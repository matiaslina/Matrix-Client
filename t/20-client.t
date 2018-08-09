use lib 'lib';
use Test;
use Matrix::Client;
plan 5;

unless %*ENV<MATRIX_CLIENT_TEST_SERVER> {
    skip-rest 'No test server setted';
    exit;
}

my $home-server = %*ENV<MATRIX_CLIENT_TEST_SERVER>;
my $username = %*ENV<MATRIX_CLIENT_USERNAME>;
my $password = %*ENV<MATRIX_CLIENT_PASSWORD>;
my $device-id = %*ENV<MATRIX_CLIENT_DEVICE_ID>;
my $access-token;
my Matrix::Client $client;

subtest 'creation' => {
    plan 2;
    $client .= new(:$home-server, :$device-id);
    isnt $client.home-server, '', 'home server isnt empty';
    isnt $client.device-id, '', 'device-id isnt empty';
    note $client.base-url;
}

subtest 'login' => {
    plan 4;
    throws-like {
        $client.login(:username<wrong>, :password<data>)
    }, X::Matrix::Response, message => /M_FORBIDDEN/;
    lives-ok { $client.login($username, $password) }, 'can logging with right data';

    isnt $client.access-token, '', 'access-token setted';
    $access-token = $client.access-token;

    my Matrix::Client $access-token-client .= new(:$home-server,
                                                  :$device-id,
                                                  :$access-token);
    ok $access-token-client.whoami.starts-with("@$username"),
       'client with access-token can do authorized calls';
}

subtest 'User data' => {
    plan 2;
    isa-ok $client.profile, Hash, '.profile returns a Hash?';

    subtest 'display name' => {
        plan 3;
        is $client.display-name, $username, 'get default display-name';
        ok $client.change-display-name('testing'), 'change display-name';
        is $client.display-name, 'testing', 'get new display-name';
        $client.change-display-name($username);
    }
}

subtest 'sync' => {
    plan 3;
    isa-ok $client.sync(), Matrix::Response::Sync,
           'sync without params is a Response';
    isa-ok $client.sync(:sync-filter('{"room": { "timeline": { "limit": 1 } } }')),
           Matrix::Response::Sync, 'sync with Str sync-filter';
    isa-ok $client.sync(:sync-filter(room => timeline => limit => 1)),
           Matrix::Response::Sync, 'sync wit Hash sync-filter';
}

subtest 'directory' => {
    plan 6;
    my $alias = '#testing:localhost';
    my $test-room = $client.create-room;

    throws-like {
        $client.get-room-id($alias);
    }, X::Matrix::Response,
       message => /M_NOT_FOUND/,
       "raises with unknown alias";

    lives-ok {
        $client.add-room-alias($test-room.id, $alias)
    }, 'can add an alias to the room';

    lives-ok {
        $client.get-room-id($alias);
    }, 'can retrieve room with an alias';

    is $client.get-room-id($alias), $test-room.id,
       'good room when retrieve';

    lives-ok {
        $client.remove-room-alias($alias);
    }, 'can remove the alias';

    throws-like {
        $client.get-room-id($alias);
    }, X::Matrix::Response,
       message => /M_NOT_FOUND/,
       "Room not found after delete";
}
