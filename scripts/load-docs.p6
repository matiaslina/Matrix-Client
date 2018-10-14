#!/usr/bin/env perl6
use v6;
use HTTP::UserAgent;
use JSON::Fast;

sub get-api-docs {
    my $url = "https://matrix.org/docs/api/client-server/json/api-docs.json";
    my $ua = HTTP::UserAgent.new;

    my $res = $ua.get($url);
    die "Cannot get response $res" unless $res.is-success;

    my $data = from-json($res.content);

    my %tags;

    for $data<paths> -> $path {
        $path.kv.map: -> $p, $methods {
            for $methods.kv -> $method, $description {
                for $description<tags> -> $tag {
                    unless %tags{$tag}:exists {
                        %tags{$tag} = Array.new;
                    }
                    %tags{$tag}.push("{$method.uc} - $p");
                }
            }
        }
    }

    %tags
}

sub MAIN(:$spec?) {
    my %tags = get-api-docs;
    for %tags.sort -> $pair {
        my $tag = $pair.key;
        my $methods = $pair.value;
        say qq:to/EOF/;
        # $tag
        EOF

        for $methods.Seq -> $m {
            my Str $method = $m;
            if $spec {
                $method = $m.subst(/unstable/, $spec)
            }
            say "- [ ] " ~ $method;
        }
        say "";
    }
}
