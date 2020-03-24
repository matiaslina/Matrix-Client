use v6;
use lib <lib>;
use Matrix::Client;
use Data::Dump::Tree;

my Matrix::Client $client .= new:
    :home-server<https://matrix.deprecated.org>,
    :access-token(%*ENV<MATRIX_ACCESS_TOKEN>);

say $client.presence(“@matias:matrix.deprecated.org”);
#`[
for ^10 -> $i {
    my $presence = $i %% 2 ?? "online" !! "offline";
    say $client.presence.presence;
    say "Setting presence $presence";
    $client.set-presence($presence, :status-message<woops>);
    sleep 3;
}
]
