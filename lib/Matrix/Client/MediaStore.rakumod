use JSON::Fast;
use URI::Escape;

use Matrix::Client::Requester;
use Matrix::Client::Exception;
use Matrix::Client::Response;

unit class Matrix::Client::MediaStore does Matrix::Client::Requester;

class Matrix::Client::MediaStore::File {
    has Str $.content-type;
    has Str $.content-disposition;
    has Buf $.content;
}

submethod TWEAK {
    # Different client endpoint for media
    $!client-endpoint = "/_matrix/media/r0";
}

method parse-mxc(Str $uri) {
    if $uri ~~ m/"mxc://" $<server-name> = [.*] "/" $<media-id> = [ .* ]/ {
        return {
            server-name => $<server-name>,
            media-id => $<media-id>
        }
    }

    X::Matrix::MXCParse.new(:$uri).throw;
}

#| POST - /_matrix/media/r0/upload
method upload(IO::Path $path, Str $filename?, Str :$content-type is copy = "image/png" --> Str) {
    my $buf = slurp $path, :bin;
    my $fn = $filename ?? $filename !! $path.basename;

    # The filename is passed on a query param.
    my $endpoint = "/upload?filename=" ~ uri-escape($fn);


    my $res = $.post-bin(
        $endpoint, $buf,
        :$content-type,
    );

    my $data = from-json($res.content);
    $data<content_uri> // "";
}

#| GET - /_matrix/media/r0/download/{serverName}/{mediaId}
multi method download(Str $mxc-uri, :$allow-remote = True, Str :$filename?) {
    my $mxc = self.parse-mxc($mxc-uri);

    samewith($mxc<server-name>, $mxc<media-id>, :$allow-remote, :$filename)
}

#| GET - /_matrix/media/r0/download/{serverName}/{mediaId}/{fileName}
multi method download(Str $server-name, Str $media-id,
                      Bool :$allow-remote = True, Str :$filename?) {
    my $endpoint = "/download/{$server-name}/{$media-id}";

    $endpoint ~= "/{$filename}" if $filename.defined;
    my $response = $.get(
        $endpoint,
        allow_remote => $allow-remote.Str.lc
    );

    my %headers = $response.header.hash();

    Matrix::Client::MediaStore::File.new(
        content-type => %headers<Content-Type>.head,
        content-disposition => %headers<Content-Disposition>.head,
        content => $response.content
    )
}

#| GET - /_matrix/media/r0/thumbnail/{serverName}/{mediaId}
multi method thumbnail(Str $mxc-uri, Int $width, Int $height,
                       Str :$method where * eq 'crop'|'scale',
                       Bool :$allow-remote = True) {
    my $mxc = self.parse-mxc($mxc-uri);
    samewith(
        $mxc<server-name>, $mxc<media-id>,
        $width, $height,
        :$method, :$allow-remote
    )
}

#| GET - /_matrix/media/r0/thumbnail/{serverName}/{mediaId}
multi method thumbnail(Str $server-name, Str $media-id,
                       Int $width, Int $height,
                       Str :$method where * eq 'crop'|'scale',
                       Bool :$allow-remote = True) {
    my $endpoint = "/thumbnail/{$server-name}/{$media-id}";

    my $response = $.get(
        $endpoint,
        :$height,
        :$width,
        :$method,
        allow_remote => $allow-remote.Str.lc
    );

    my %headers = $response.header.hash();

    Matrix::Client::MediaStore::File.new(
        content-type => %headers<Content-Type>.head,
        content => $response.content
    )
}

#| GET - /_matrix/media/r0/config
method config(--> Matrix::Client::Response::MediaStore::Config) {
    my $response = $.get("/config");
    Matrix::Client::Response::MediaStore::Config.new(from-json($response.content))
}
