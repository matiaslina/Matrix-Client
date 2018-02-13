#!/usr/bin/env perl6
use v6;
use lib "lib";
use JSON::Tiny;
use Matrix::Client;
use Matrix::Client::Exception;

class Bot {
    has $!name = "!d";
    has $!username is required;
    has Bool $!register = False;

    has $!on-event;

    has Matrix::Client $!client;

    submethod BUILD(:$username!, :$password!, :$home-server!,:$on-event!) {
        $!client = Matrix::Client.new(:home-server($home-server));
        $!username = $username;
        $!on-event = $on-event;

        $!client.login($!username, $password);
    }

    method shutdown() {
        $!client.save-auth-data;
    }

    method listen() {
        say "Listening";
        my $since = "";

        loop {
            my $sync = { room => timeline => limit => 1 };
            my $response = $!client.sync(sync-filter => $sync, since => $since);
            $since = $response.next-batch;
            
            for $response.joined-rooms -> $room {
                for $room.timeline
                         .events
                         .grep(*.type eq 'm.room.message') -> $msg {
                    if $msg.content<body>.match($!name) {
                        my $bot-msg = $!on-event($msg);
                        if so $bot-msg {
                            say "Sending message $bot-msg";
                            try {
                                CATCH { when X::Matrix::Response { .message }}
                                my $res = $!client.send($room.room-id, ~$bot-msg);
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
    my $bot = Bot.new:
        username => $username,
        password => $password,
        home-server => $home-server,
        on-event => -> $ev {
            given $ev.content<body> {
                when /"say hi"/ {
                    say "Someone says {$ev.content<body>}";
                    "Hello @ {DateTime.now}"
                }
                default { say "Dunno what's telling me"; Str }
            }
        };

    signal(SIGINT).tap({
        say "Bye";
        $bot.shutdown;
        exit 0;
    });

    $bot.listen;
}
