(function($){
  $.fn.addBsAlert= function(options){
    var settings = $.extend({
            
            classes: "alert",
            strong: "Alert",
            text: "Something is up!"
        }, options );
    var  alert = $('<div />');
    alert.addClass(settings.classes);
    alert.append($('<button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>'))
      .append($('<strong>' + settings.strong + '</strong><span> ' + settings.text + ' </span>'));
    return $(this).after(alert);
  }

  $.fn.addFormFields = function(options){
    // applying settings for the function.
    var count = 0;
    var settings = $.extend({
      target: null,
      titleText: 'Remove Element',
      removeButton: $('<button type="button" class="btn btn-danger"><i class="icon-remove"></i></button>'),
     }, options);
    
    //adding some error handling here.
    if (settings.target == null ){
      console.log('must provide target: ' + this);
      return;
    }

    //adding the click event to handle adding form fields.
    this.click(function(){

      var $cloned = settings.target.first().clone();
      $cloned.addClass('input-append');
      var $removeButton = settings.removeButton.clone().attr('title', settings.titleText);
      $removeButton.click(function(){
        $cloned.remove();
      });
      //label the cloned fields.
      $cloned.find('label').each(function(){
        var forId = $(this).attr('for') + count;
        $(this).attr('for', forId);
        $(this).next('input, select').val("").attr('id', forId);
      });
      //add the cloned elements.
      settings.target.after($cloned);
      var lastInput = $cloned.find('input, select').last();
      
      lastInput.after($removeButton.tooltip());
      // lastInput.width(function(i, width){
      //     return width - $removeButton.outerWidth() - 2;
      //   });
      count++;
    });

  };




  // $.rails.allowAction = function(element) {
  // var message = element.data('confirm'),
  //   answer = false, callback;
  // if (!message) { return true; }
 
  // if ($.rails.fire(element, 'confirm')) {
  //   drsConfirmMessage(message, function() {
  //     callback = $.rails.fire(element,
  //       'confirm:complete', [answer]);
  //       if(callback) {
  //         var oldAllowAction = $.rails.allowAction;
  //         $.rails.allowAction = function() { return true; };
  //         element.trigger('click');
  //         $.rails.allowAction = oldAllowAction;
  //       }
  //     });
  //   }
  //   return false;
  // }
 
  // function drsConfirmMessage(message, callback) {
  //   bootbox.confirm(message, "Cancel", "Yes", function(confirmed) {
  //     if(confirmed){
  //       callback();
  //     }
  //   });
  // }

}(jQuery));