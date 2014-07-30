/*jshint es5:true expr:true */

suite('Placeholder Active', function () {
    // patch placeholder test function
    Placeholder.prototype._testForPlaceholder = function () {
        return false;
    };
    window.ph = new Placeholder();

    var val = 'Placeholder',
        iclass = ph.config.classnames.state_inactive,
        aclass = ph.config.classnames.state_active;

    test('Placeholder should be a function', function() {
        Placeholder.should.be.a('function');
    });

    test('Placeholder instance "ph" should be instance of Placeholder',
    function() {
        ph.should.be.instanceOf(Placeholder);
    });

    test('Elements with Placeholders should be selected', function () {
        ph.$elements.should.have.length(2);
    });

    test('Parent form should be selected', function () {
        ph.$form.should.have.length(1);
    });

    test('Element should contain value of placeholder attribute',
    function () {
        ph.$elements.attr('value').should.eql(val);
    });

    test('Element should have inactive class', function () {
        var iclass = ph.config.classnames.state_inactive;

        ph.$elements.hasClass(iclass).should.be['true'];
    });

    test('Element should have empty value and active class when focused',
    function () {
        ph.$elements.each(function(i, obj) {
            var $obj = $(obj);

            $obj.focus().val().should.eql('');
            $obj.hasClass(aclass).should.be['true'];
        });
    });

    test('Element should have original value and inactive class when blurred',
    function () {
        ph.$elements.blur();

        ph.$elements.val().should.eql(val);
        ph.$elements.hasClass(iclass).should.be['true'];
    });

    test('On user input, placeholder should not repopulate on blur',
    function () {
        var newinput = "user input";

        ph.$elements.focus().val(newinput).blur();
        ph.$elements.val().should.eql(newinput);
    });

    test('On reactivation of form, input should not clear',
    function () {
        var newinput = "user input";

        ph.$elements.val(newinput).focus();
        ph.$elements.val().should.eql(newinput);
    });

    test('On form submit, inputs with no user interaction should be blank',
    function () {
        ph.$form.submit(function(evt) {
            evt.preventDefault();

            ph.$elements.each(function (i, obj) {
                $(obj).val().should.eql('');
            });
        });
    });
});
