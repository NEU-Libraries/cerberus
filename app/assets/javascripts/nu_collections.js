//Handles spawning new permission related form elements on the nu_collections/new page.  
$(document).ready(function () {
  'use strict';
  //Add a datepicker to the date of issuance field. 
  $('#date-issued, #embargo-date').datepicker({
    todayBtn: true,
    todayHighlight: true,
    clearBtn: true
  });


  var count = 0;
  $.fn.addFormFields = function(options){
    // applying settings for the function.
    var settings = $.extend({
      target: null,
      titleText: 'Remove Element',
      removeButton: $('<button type="button" class="btn btn-danger"><i class="icon-remove"></i></button>'),
     }, options);
    
    //adding some effor handling here.
    if (settings.target == null ){
      console.log('must provide target: ' + this);
      return;
    }

    //adding the click event to handle adding form fields.
    this.click(function(){

      var $cloned = settings.target.first().clone();
      var $removeButton = settings.removeButton.clone().attr('title', settings.titleText);
      $removeButton.click(function(){
        $cloned.remove();
      });
      //label the cloned fields.
      $cloned.find('label').each(function(){
        var forId = $(this).attr('for') + count;
        $(this).attr('for', forId);
        $(this).next('input, select').attr('id', forId);
      });
      //add the cloned elements.
      settings.target.after($cloned);
      $cloned.find('input, select').last().after($removeButton);
      count++
    });

  };

  $('#add_another_personal_creator').addFormFields({
    target: $('div.personal_creator'),
  });

  $('#add_another_corporate_creator').addFormFields({
    target: $('div.corporate_creator'),
  });  

  $('#add_another_keyword').addFormFields({
    target: $('div.keyword'),
  });
  $('#add_another_permission').addFormFields({
    target: $('div.permission'),
  });

});