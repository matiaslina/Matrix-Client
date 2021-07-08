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

As an example, I will be using the [ban](https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-rooms-roomid-ban) endpoint.

We know from the specification that:

- It's a `POST`.
- The endpoint is `/_matrix/client/r0/rooms/{roomId}/ban`.
- Requires authentication.
- Has two required parameters.
  + `room_id`: It's on the URL.
  + `user_id`: This is the user that we wan't to ban.
- Has an optionas parameter: the `reason`.

With this information we can make the signature of the method on the
`Matrix::Client::Room` class.

```raku
method ban(Str $user-id, $reason = "") {
```

We don't need to specify the `room_id` because it's already an attribute of the class.

Because the Room class `does Matrix::Client::Requester`, we have all the
methods to make an http request. This also handles authentication.

We'll call the `$.post` method with the endpoint as it's first parameter
and the rest of the named parameters will be the `user_id` and the `reason`. All
named parameters will be passed into the body of the json.

The `Matrix::Client::Room` class already prepends the first part of the endpoint (
`/_matrix/client/r0/rooms/{roomId}`) so we only specify what's after the `{roomId}` part
of the url.

```raku
    $.post('/ban', :user_id($user-id), :$reason)
```

And done :)

After that, you should add the `ban` method also to the `Matrix::Client` class
instantiating a `Matrix::Client::Room` with a `$room-id` argument.

```raku
class Matrix::Client does Matrix::Client::Requester {
    # ...

    method ban(Str $room-id, $user-id, :$reason) {
        Matrix::Client::Room.new(
            :id($room-id),
            :access-token(self.access-token),
            :home-server(self.home-server)
        ).ban(
            $user-id,
            :$reason
        )
    }

    # ...
}
```
