use v6;
use Matrix::Client;

my $c = Matrix::Client.new: :home-server<https://matrix.deprecated.org>;
$c.login: @*ARGS[0], @*ARGS[1];

say $c.rooms(:sync);
