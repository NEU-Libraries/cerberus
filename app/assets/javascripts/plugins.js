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

}(jQuery));