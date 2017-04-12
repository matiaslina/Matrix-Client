use HTTP::UserAgent;
use HTTP::Request::Common;
use URI::Encode;
use JSON::Tiny;

unit role Matrix::Client::Requester;

has $!ua = HTTP::UserAgent.new;
has $.home-server is required;
has $!client-endpoint = "/_matrix/client/r0";
has $!url-prefix = "";
has $!access-token = "";
has $!sync-since = "";

method get(Str $path, :$media = False, *%data) {
    my $q = "$path?access_token=$!access-token";
    for %data.kv -> $k,$v {
        $q ~= "&$k=$v" unless $v eq "";
    }
    my $uri = uri_encode($.base-url(:$media) ~ $q);

    $!ua.history = [];
    $!ua.get($uri)
}

method base-url(Bool :$media? = False --> Str) {
    if !$media {
        "$.home-server$!client-endpoint$!url-prefix"
    } else {
        "$.home-server/_matrix/media/r0"
    }
}

multi method post(Str $path, Str $json, :$media = False) {
    my $req = HTTP::Request.new(POST => $.base-url(:$media) ~ $path ~ "?access_token=$!access-token",
                                Content-Type => 'application/json');
    $req.add-content($json);
    $!ua.history = [];
    $!ua.request($req)
}

method post-bin(Str $path, Buf $buf, :$content-type) {
    my $req = POST($.base-url(:media) ~ $path ~ "?access_token=$!access-token", content => $buf, Content-Type => $content-type);
    $!ua.history = [];
    $!ua.request($req)
}

multi method post(Str $path, :$media = False, *%params) {
    self.post($path, :$media, to-json(%params))
}

multi method put(Str $path,Str $json) {
    my $req = HTTP::Request.new(PUT => $.base-url() ~ $path ~ "?access_token=$!access-token",
                                Content-Type => 'application/json');
    $req.add-content($json);
    $!ua.history = [];
    $!ua.request($req)
}

multi method put(Str $path, *%params) {
    self.put($path, to-json(%params))
}
