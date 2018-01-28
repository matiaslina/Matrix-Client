use v6;
use Matrix::Client;


sub MAIN($username, $pass) {
    my $c = Matrix::Client.new(home-server => 'https://matrix.deprecated.org');
    $c.login: $username, $pass;

    for $c.joined-rooms -> $room {
        $room.say;
    }
}
