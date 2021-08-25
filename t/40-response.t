use lib 'lib';
use Test;
use JSON::Fast;
plan 3;

use-ok 'Matrix::Client::Response';
use Matrix::Client::Response;

subtest 'Sync', {
    plan 7;
    my $test-file = 'sync.json';
    my $data;

    if $test-file.IO.f {
        $data = from-json($test-file.IO.slurp);
        lives-ok { Matrix::Client::Response::Sync.new($test-file.IO.slurp) }, 'Sync.new accepts Str';
        lives-ok { Matrix::Client::Response::Sync.new($data) }, 'Sync.new accepts Associative';

        my $res = Matrix::Client::Response::Sync.new($data);
        can-ok $res, 'joined-rooms', 'can .joined-rooms';
        can-ok $res, 'presence', 'can .presence';

        isa-ok $res.joined-rooms, List, '.joined-rooms returns a List';
        isa-ok $res.presence, List, '.presence returns a List';

    } else {
        skip 'Missing sync.json to test', 7;
    }

};

subtest 'MediaStore', {
    plan 4;
    my %config = 'm.upload.size' => 5000;
    my $config-response = Matrix::Client::Response::MediaStore::Config.new(%config);

    isa-ok $config-response, Matrix::Client::Response::MediaStore::Config;
    can-ok $config-response, 'upload-size';
    isa-ok $config-response.upload-size, Int;
    is $config-response.upload-size, %config<m.upload.size>, 'correct upload size';
};
