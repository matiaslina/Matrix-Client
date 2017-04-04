# Matrix client

Simple [matrix](https://matrix.org) client.

# Examples

From the `examples` directory:

    use v6;
    use Matrix::Client;

    # Instantiate a new client for a given home-server
    my $client = Matrix::Client.new: :home-server<https://matrix.org>
    # Login
    $client.login: @*ARGS[0], @*ARGS[1];

    # Show all joined rooms
    say $client.rooms;

    # And finally logout.
    $client.logout
