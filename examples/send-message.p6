#!/usr/bin/env perl6
use v6;
use lib 'lib';
use Matrix::Client;

sub MAIN(:$room-id?, :$room-alias?, *@args) {
    unless $room-id.so || $room-alias.so {
        fail 'Missing room-id or room-alias';
    }
    my Matrix::Client $client .= new:
        :home-server(%*ENV<MATRIX_HOMESERVER>),
        :access-token($*ENV<MATRIX_ACCESS_TOKEN>);

    my $id;
    if $room-id.so {
        $id = $room-id;
    } else {
        say "Searching for $room-alias";
        $id = $client.get-room-id($room-alias);
    }

    my $event = $client.send($id, @args.join(' '));
    say $event;
}
