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

method get(Str $path, *%data) {
    my $q = "$path?access_token=$!access-token";
    for %data.kv -> $k,$v {
        $q ~= "&$k=$v" unless $v eq "";
    }
    my $uri = uri_encode($.base-url ~ $q);

    $!ua.history = [];
    $!ua.get($uri)
}

method base-url(--> Str) {
    "$.home-server$!client-endpoint$!url-prefix"
}

multi method post(Str $path, Str $json) {
    my $req = HTTP::Request.new(POST => $.base-url() ~ $path ~ "?access_token=$!access-token",
                                Content-Type => 'application/json');
    $req.add-content($json);
    $!ua.history = [];
    $!ua.request($req)
}

multi method post(Str $path, *%params) {
    self.post($path, to-json(%params))
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
