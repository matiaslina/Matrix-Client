# Matrix client

A perl 6 library for [Matrix](https://matrix.org).

## Status

This project is in early development. A lot of methods return a raw
`HTTP::Response` and not something from this library.

## Examples

From the `examples` directory:

    use v6;
    use Matrix::Client;

    # Instantiate a new client for a given home-server
    my $client = Matrix::Client.new: :home-server<https://matrix.org>
    # Login
    $client.login: @*ARGS[0], @*ARGS[1];

    # Show all joined rooms
    say $client.rooms(:sync);

    # And finally logout.
    $client.logout
