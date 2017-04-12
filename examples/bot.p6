#!/usr/bin/env perl6
use v6;
use lib "lib";
use JSON::Tiny;
use Matrix::Client;

class Bot {
    has $!name = "!d";
    has $!username is required;
    has Bool $!register = False;
    has @!room-ids;

    has $!on-event;

    has Matrix::Client $!client;

    submethod BUILD(:$username!, :$password!, :$home-server!, :@room-ids!, :$on-event!) {
        $!client = Matrix::Client.new(:home-server($home-server));
        $!username = $username;
        @!room-ids = @room-ids;
        $!on-event = $on-event;

        $!client.login($!username, $password);
    }

    method join-rooms() {
        @!room-ids.map: { $!client.join-room($_) }
    }

    method shutdown() {
        $!client.save-auth-data;
    }

    method listen() {
        say "Listening";
        my $since = "";

        loop {
            my $sync = { room => timeline => limit => 1 };
            my $data = from-json($!client.sync(sync-filter => $sync, since => $since).content);
            $since = $data<next_batch>;
            
            for $data<rooms><join>.kv -> $room-id, $d {
                for @($d<timeline><events>) -> $ev {
                    if $ev<type> eq "m.room.message" {
                        if $ev<content><body>.match($!name) {
                            my $bot-msg = $!on-event($ev);
                            if so $bot-msg {
                                say "Sending message $bot-msg";
                                my $res = $!client.send($room-id, ~$bot-msg);
                                if $res.is-success {
                                    say $res.content;
                                } else {
                                    warn $res.content;
                                    die $res.status-line;
                                }
                            }
                        }
                    }
                }
            }
            sleep(10);
        }
    }
}

sub MAIN(Str:D $username, Str:D $password, :$home-server = "https://matrix.deprecated.org") {
    my @rooms = "!bpHGYOiCGlvCZarfMH:matrix.deprecated.org";
    my $bot = Bot.new:
        username => $username,
        password => $password,
        home-server => $home-server,
        room-ids => @rooms,
        on-event => -> $ev {
            given $ev<content><body> {
                when /"say hi"/ {
                    say "Someone is saying hi!";
                    "Hello @ {DateTime.now}"
                }
                when /poop/ {
                    parse-names "PILE OF POO"
                }
                when /wink/ {
                    parse-names "WINKING FACE"
                }
                default { say "Dunno what's telling me"; Str }
            }
        };

    signal(SIGINT).tap({
        say "Bye";
        $bot.shutdown;
        exit 0;
    });

    my $ress = $bot.join-rooms;
    for @($ress) -> $res {
        if !$res.is-success {
            warn $res.status-line;
            warn $res.content;
            die "Error joinig to rooms";
        }
    }
    
    $bot.listen;
}
