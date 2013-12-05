/* wrapper for 'mocha-phantomjs' for a grunt task */

module.exports = function (grunt) {

    grunt.registerMultiTask('mocha', 'Run Mocha tests in a PhantomJS Instance',
        function () {

        var done = this.async();

        var files = grunt.file.expandFiles(this.file.src)
            .forEach(function (filepath) {

                grunt.utils.spawn({
                    cmd: 'mocha-phantomjs',
                    args: [ filepath ]
                }, function (err, result, code) {
                    if (!err) {
                        grunt.log.write(result);

                        done(null);
                    } else {
                        grunt.log.write(result.stdout);

                        grunt.warn('Task exited unexpectedly with exit code ' + code + '.', code);
                        done(code);
                    }
                });

            });
    });
};
