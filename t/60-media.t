use lib 'lib';
use Test;
use Matrix::Client::MediaStore;
use Matrix::Client::Exception;

plan 6;

my $path = $*TMPDIR.add('matrix-client-test');
LEAVE { unlink $path; }
$path.spurt("") unless $path.f;

# Mock the post-bin method of Matrix::Client::Requester.
my $media = Matrix::Client::MediaStore.new(:home-server("1234")) but role {
    has %.called-with;
    method post-bin(Str $path, Buf $buf, :$content-type) {
        %.called-with<path> = $path;
        %.called-with<buf> = $buf;
        %.called-with<content-type> = $content-type;

        class { method content { '{"content_uri": "bla" }' } }
    }
}


$media.upload($path, "something");
is $media.called-with<path>, '/upload?filename=something', "Send filename pass by parameter";

$media.upload($path, "something with spaces");
is $media.called-with<path>, '/upload?filename=something%20with%20spaces', "Escaped filename";

$media.upload($path);
is $media.called-with<path>, "/upload?filename={$path.basename}", "Send file basename if not set";
is $media.called-with<content-type>, 'image/png', "By default use `image/png` MIME";

$media.upload($path, content-type => 'application/pdf');
is $media.called-with<content-type>, 'application/pdf', "Can change the content type";

subtest {
    plan 2;
    my $media = Matrix::Client::MediaStore.new(:home-server("1234"));
    is $media.parse-mxc("mxc://matrix.org/123456.pdf"), {
        server-name => "matrix.org", media-id => "123456.pdf"
    }, 'Simple parsing';

    throws-like {
        $media.parse-mxc("http://matrix.org/123456.pdf")
    }, X::Matrix::MXCParse, 'Dies with HTTP URI';

}, 'mxc parsing';
