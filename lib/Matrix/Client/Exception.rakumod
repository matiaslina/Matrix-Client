module Matrix::Client::Exception {

    class X::Matrix::Response is Exception {
        has $.code;
        has $.error;

        method message(--> Str) {
            "$!code: $!error"
        }
    }

    class X::Matrix::MXCParse is Exception {
        has $.uri;

        method message { "Cannot parse '$!uri'" }
    }
}
