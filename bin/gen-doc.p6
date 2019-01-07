use v6;
use Pygments;

my %*POD2HTML-CALLBACKS;
%*POD2HTML-CALLBACKS<code> = sub (:$node, :&default) {
    Pygments.highlight($node.contents.join('\n'), "perl6",
                       :style(Pygments.style('emacs')))
};

use Pod::To::HTML;
use Pod::Load;
use Template::Mustache;

sub git-version {
    run('git', 'tag', '-l', :out).out.lines.first
}
sub pods { dir('./docs', :test( *.IO.extension eq 'pod'|'pod6' )) }

my $sidebar = pods.sort.map(
    -> $p {
        my $f = $p.IO.extension('html').basename;
        "<li><a href='$f'>{$f.split('.').first.tc}</a></li>"
    });

sub MAIN(:o(:$output-dir)?) {
    $output-dir.IO.add('index.html').spurt(
        Template::Mustache.render('./templates/index.mustache'.IO.slurp,
                                  {version => git-version()}));

    pods.map(
        -> $pod {
            say "Generating html for $pod";
            next if $pod.IO.extension ne 'pod'|'pod6';
            my $html = pod2html(
                load($pod.IO),
                :templates<templates>
            );

            my $filename = $pod.IO.extension('html');
            my $output = $output-dir.defined ??
            $output-dir.IO.add($filename.basename) !!
            $filename;

            spurt $output, $html;
        });
}
