use JSON::Tiny;

unit module Matrix::Response;

class Matrix::Response::Event {
    has %.content;
    has $.type is required;

    method gist(--> Str) {
        "Event<$.type>"
    }
}

class Matrix::Response::RoomEvent is Matrix::Response::Event {
    has Str $.sender;
    has Int $.origin_server_ts;
    has $.event_id;
    has Str $.room_id;

    method id { $.event_id }
    method timestamp { $!origin_server_ts }
    method room-id { $.room-id }
}

class Matrix::Response::StateEvent is Matrix::Response::RoomEvent {
    has $.prev_content;
    has $.state_key;
}

class Matrix::Response::Timeline {
    has Matrix::Response::Event @.events;
    has Bool $limited;
    has Str $prev-batch;
}

class Matrix::Response::RoomInfo {
    has $.room-id is required;
    has Matrix::Response::Event @.state;
    has Matrix::Response::Timeline $.timeline;

    method gist(--> Str) {
        "<Matrix::Response::RoomInfo: $.room-id>"
    }
}

sub gather-events($from) {
    gather for $from<events>.List -> $ev {
        take Matrix::Response::StateEvent.new(|$ev);
    }
}

class Matrix::Response::Sync {
    has Str $.next-batch;
    has Matrix::Response::Event @.presence;
    has Matrix::Response::RoomInfo @.joined-rooms;

    multi method new(Str $json) {
        return self.new(from-json($json));
    }

    multi method new(Hash $json) {
        my $next-batch = $json<next_batch>;
        my Matrix::Response::Event @presence;
        my Matrix::Response::RoomInfo @joined-rooms;
        
        for $json<presence><events>.List -> $ev {
            @presence.push(Matrix::Response::Event.new(|$ev));
        }

        for $json<rooms><join>.kv -> $room-id, $data {
            my @state = gather-events($data<state>);

            my $timeline = Matrix::Response::Timeline.new(
                limited => $data<timeline><limited>,
                prev-batch => $data<timeline><prev_batch>,
                events => gather-events($data<timeline>)
            );

            @joined-rooms.push(Matrix::Response::RoomInfo.new(
                :$room-id, :$timeline, :@state
            ));
        }

        return self.bless(:$next-batch, :@presence, :@joined-rooms);
    }
}
