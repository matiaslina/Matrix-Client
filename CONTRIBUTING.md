# How to contribute to Matrix::Client

## The Contribution Process

For small changes, feel free to submit a pull request on Github.

This includes:

* Bug fixes
* Missing arguments in existing endpoints
* Implement a new endpoint

If you need guidance or want to discuss something before working on the
code,
[open an issue](https://github.com/matiaslina/Matrix-Client/issues/new) on
Github.

If you don't get feedback on your pull request, feel free to poke me
via email or Matrix. You can find them on the [README.md](README.md).

## Coding style

Please match your coding style to that of the code around it :)

# Architecture overview

## Matrix::Client

This is the main class that implements all the API and must be
posible to do every action of the API from an instance of the client.

## Matrix::Client::Room

This class represents an instance of a single room, identified by
its `room_id`.

The methods that this class should expose are the endpoints that have
the prefix `/_matrix/client/r0/rooms/{roomId}` from the
[Matrix client-server Specification](https://matrix.org/docs/spec/client_server/r0.6.1).

If there's a method on `Matrix::Client::Room` but not a similar method
on `Matrix::Client`, that is considered a bug (for example:
`Matrix::Client.ban` and `Matrix::Client::Room.ban`). This is to avoid
that the user to instanciate a new `Matrix::Client::Room` and then
call the method.

## Matrix::Client::Requester

This role implements the http methods `GET`, `POST`, `PUT`, etc. when
interfacing with a home server. This is necesary for a couple of
reasons:

* Correct encoding of url queryparms
* Set the correct headers
* Handle errors in a consistent manner

The `Matrix::Client` and `Matrix::Client::Room` use this role.

## Matrix::Client::Response

The module `Matrix::Client::Response` have all the classes that are
used to wrap the HTTP responses from the home server.

There's nothing to crazy here. For the most part there's some `_` to
`-` conversion for the JSON keys -> raku objects and to remove
unnecessary keys.

## Matrix::Client::Common::TXN-ID

This variable it's used every time there's a need for a transaction
id.

You must increment this variable on use. A
`$Matrix::Client::Common::TXN-ID++;` is enough.

# How do I...

## Add a new endpoint?
