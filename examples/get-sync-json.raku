use v6;
use Matrix::Client;

sub MAIN($file? = 'sync.json') {
    my $c = Matrix::Client.new(home-server => 'https://matrix.deprecated.org');
    $c.login: 'deprecated_bot', 'deprecatedbot';

    my $res = $c.sync;
    $file.IO.spurt($res.content);

    $c.logout;
}
