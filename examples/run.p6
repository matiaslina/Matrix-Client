#!/usr/bin/env perl6
use v6;
use lib <lib>;
use Matrix::Client;

sub MAIN(Str:D $username, Str:D $password, :$home-server = "https://matrix.deprecated.org") {
    my Matrix::Client $client .= new: :$home-server;
    $client.login($username, $password);

    my $sup = $client.run(:sleep<5>);

    signal(SIGINT).tap({
        say "Bye";
        $client.logout;
        exit 0;
    });

    react whenever $sup -> $ev {
        say $ev;
    }
}
