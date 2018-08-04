use lib 'lib';
use Test;
use Matrix::Client;
use Matrix::Client::Exception;

plan 1;

my $c = Matrix::Client.new(:home-server<https://matrix.org>);

throws-like {
    $c.get('/unknown-endpoint');
}, X::Matrix::Response, 'Unknown endpoint throws exception';
