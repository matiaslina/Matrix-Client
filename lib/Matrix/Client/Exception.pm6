package X::Matrix {
    class Response is Exception {
        has $.code;
        has $.error;

        method message {
            "$!code: $!error"
        }
    }
}
