use JSON::Fast;

unit module Matrix::Client::Response;

class Event {
    has %.content;
    has $.type is required;
}

class RoomEvent is Event {
    has Str $.sender;
    has Int $.origin_server_ts;
    has $.event_id;
    has Str $.room_id;

    method id { $.event_id }
    method timestamp { $!origin_server_ts }
    method room-id { $.room_id }
}

class StateEvent is RoomEvent {
    has $.prev_content;
    has $.state_key;
}

class MemberEvent is StateEvent {
    has $.type is required where 'm.room.member';
}

class Timeline {
    has Event @.events;
    has Bool $limited;
    has Str $prev-batch;
}

class RoomInfo {
    has $.room-id is required;
    has Event @.state;
    has Timeline $.timeline;

    method gist(--> Str) {
        "<RoomInfo: $.room-id>"
    }
}

class InviteInfo {
    has $.room-id is required;
    has Event @.events;

    method gist(--> Str) {
        "<InviteState: $.room-id>"
    }
}

sub gather-events($room-id, $from) {
    gather for $from<events>.List -> $ev {
        take StateEvent.new(:room_id($room-id), |$ev);
    }
}

class Messages {
    has $.start;
    has $.end;
    has RoomEvent @.messages;
}

class Sync {
    has Str $.next-batch;
    has Event @.presence;
    has RoomInfo @.joined-rooms;
    has InviteInfo @.invited-rooms;

    multi method new(Str $json) {
        return self.new(from-json($json));
    }

    multi method new(Hash $json) {
        my $next-batch = $json<next_batch>;
        my Event @presence;
        my RoomInfo @joined-rooms;
        my InviteInfo @invited-rooms;

        for $json<presence><events>.List -> $ev {
            @presence.push(Event.new(|$ev));
        }

        for $json<rooms><join>.kv -> $room-id, $data {
            my @state = gather-events($room-id, $data<state>);

            my $timeline = Timeline.new(
                limited => $data<timeline><limited>,
                prev-batch => $data<timeline><prev_batch>,
                events => gather-events($room-id, $data<timeline>)
            );

            @joined-rooms.push(RoomInfo.new(
                :$room-id, :$timeline, :@state
            ));
        }

        for $json<rooms><invite>.kv -> $room-id, $data {
            my @events = gather-events($room-id, $data<invite_state>);
            @invited-rooms.push(InviteInfo.new(
                :$room-id, :@events
            ));
        }

        return self.bless(:$next-batch, :@presence,
                          :@joined-rooms, :@invited-rooms);
    }
}

class Presence {
    has Str $.presence is required;
    has Int $.last-active-ago;
    has Str $.status-message;
    has Bool $.currently-active;

    submethod BUILD(
        Str :$!presence,
        :last_active_ago(:$!last-active-ago) = 0,
        :status_message(:$!status-message) = "",
        :currently_active(:$!currently-active) = False
    ) { }
}

class Tag {
    has @.tags;

    method new(%json) {
        my @tags = %json<tags>.keys;
        self.bless(:@tags)
    }
}

class Device {
    has Str $.device-id;
    has $.display-name;
    has $.last-seen-ip;
    has $.last-seen-ts;

    submethod BUILD(
        Str :device_id(:$!device-id),
        :display_name(:$!display-name)?,
        :last_seen_ip(:$!last-seen-ip)?,
        :last_seen_ts(:$!last-seen-ts)?
    ) { }
}

class MediaStore::Config {
    has Int $.upload-size;

    method new(%config) {
        self.bless(:upload-size(%config<m.upload.size> // Int));
    }
}
