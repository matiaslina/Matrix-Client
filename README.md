# Matrix::Client

A [Raku](https://raku.org) library for [Matrix](https://matrix.org).

## Installation

    zef install Matrix::Client

## Usage

    use Matrix::Client;

    my $client = Matrix::Client.new(
        :home-server<https://matrix.org>,
        :device-id<matrix-client>
    );

    $client.login(:username<myuser>, :password<s3cr3t>);

    # Check my user
    say $client.whoami;  # @myuser:matrix.org

    # Send a message to a random room that I'm in
    my $room = $client.joined-rooms.pick;
    say "Sending a message to {$room.name}";
    $room.send("Hello from Raku!");

## Description

Matrix is an open network for secure, decentralized communication.

This module provides an interface to interact with a Matrix homeserver through
the *Client-Server API*. It's currenlty on active development but it's mostly
stable for day to day use.

Here's a not complete list of things that can be done:

* Login/logout
* Registration
* Synchronization of events/messages
* Send events
* Send messages
* Upload files to a home-server

There are many missing endpoints (you can check a complete checklist
[here](https://github.com/matiaslina/perl6-matrix-client/blob/master/endpoints.md)).
If you want to contribute with some endpoint check the
[CONTRIBUTING.md](CONTRIBUTING.md) file.

## Documentation

There's a couple of pages of documentation on the `docs/` directory. This
includes API documentation, basic usage, examples, etc.

## Author

Matías Linares <matias@deprecated.org> | Matrix ID: `@matias:chat.deprecated.org`
