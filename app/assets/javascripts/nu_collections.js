//Handles spawning new permission related form elements on the nu_collections/new page.  
$(document).ready(function () {
  'use strict';
  //Add a datepicker to the date of issuance field. 
  $('#date-issued, #embargo-date').datepicker({
    todayBtn: true,
    todayHighlight: true,
    clearBtn: true
  });


  



  // Adding the form fields behavior to the buttons on the nu collections.
  $('#add_another_personal_creator').addFormFields({
    target: $('div.personal_creator'),
    titleText: "Remove Personal Creator"
  });

  
  $('#add_another_corporate_creator').addFormFields({
    target: $('div.corporate_creator'),
    titleText: "Remove Corporate Creator",
  });  


  $('#add_another_keyword').addFormFields({
    target: $('div.keyword'),
    titleText:  "Remove keyword"
  });
  $('#add_another_permission').addFormFields({
    target: $('div.permission'),
    titleText: "Remove permission"
  });

});