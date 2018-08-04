use lib 'lib';
use Test;
use JSON::Tiny;
use Matrix::Response;
plan 7;

my $test-file = 'sync.json';

unless $test-file.IO.f {
    skip-rest 'Missing sync.json to test';
    exit;
}

my $data = from-json($test-file.IO.slurp);

ok $data;
lives-ok { Matrix::Response::Sync.new($test-file.IO.slurp) };
lives-ok { Matrix::Response::Sync.new($data) };

my $res = Matrix::Response::Sync.new($data);
can-ok $res, 'joined-rooms';
can-ok $res, 'presence';

isa-ok $res.joined-rooms, List;
isa-ok $res.presence, List;
