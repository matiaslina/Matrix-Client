### multi method tags

```perl6
multi method tags(
    Str $room-id,
    Str:D $tag,
    $order
) returns Mu
```

PUT - /_matrix/client/r0/user/{userId}/rooms/{roomId}/tags/{tag}

### multi method tags

```perl6
multi method tags(
    Str $room-id
) returns Mu
```

GET - /_matrix/client/r0/user/{userId}/rooms/{roomId}/tags

### method remove-tag

```perl6
method remove-tag(
    Str $room-id,
    Str:D $tag
) returns Mu
```

DELETE - /_matrix/client/r0/user/{userId}/rooms/{roomId}/tags/{tag}

