module.exports = function(grunt) {

    grunt.loadTasks('tasks');

    grunt.initConfig({
        pkg: '<json:package.json>',

        lint: {
            all: ['js/<%= pkg.name %>.js', 'test/*.test.js']
        },

        jshint: {
            options: {
                es5: true,
                expr: true
            }
        },

        mocha: {
            test: {
                src: [ 'test/index.html' ]
            }
        },

        watch: {
            files: '<config:lint.all>',
            tasks: 'lint mocha'
        },

        min: {
            dist: {
                src: ['js/placeholder.js'],
                dest: 'dist/placeholder.min.js'
            }
        }
    });

    grunt.registerTask('default', 'lint mocha min');
};
