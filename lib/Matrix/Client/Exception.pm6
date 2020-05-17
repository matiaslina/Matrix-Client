package X::Matrix {
    class Response is Exception {
        has $.code;
        has $.error;

        method message {
            "$!code: $!error"
        }
    }

    class MXCParse is Exception {
        has $.uri;

        method message { "Cannot parse '$!uri'" }
    }
}
