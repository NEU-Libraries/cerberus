//Handles spawning new permission related form elements on the nu_collections/new page.  
$(document).ready(function () {
  'use strict';

  //Add a datepicker to the date of issuance field. 
  $('#nu_collection_date_of_issue').datepicker({
    dateFormat: 'yy-mm-dd',
    defaultDate: null
  });

  $('input#nu_collection_embargo_release_date').datepicker({
    dateFormat: 'yy-mm-dd',
    defaultDate: + 1,
    minDate: + 1
  }); 

  //Clones the personal creator field on the 'new' form.
  $('#add_another_personal_creator').click(function() {
    var cloned = $('div.personal_creator').first().clone();
    var remove_button = "<button type='button' class='remove_personal_creator'>Remove Personal Creator</button>"; 

    cloned.find('label').text('Additional personal contributor'); 
    cloned.find('input:text').val('');
    cloned.find('input:text').attr('required', 'true'); 

    $('div.personal_creator').last().after(cloned);
    $('div.personal_creator').last().find('input:text').last().after(remove_button);
  });

  //Removes the personal creator field for this button on the 'new' form. 
  $('form').on('click', '.remove_personal_creator', function() {
    var target = $(event.target);
    target.parents('.personal_creator').remove();
  });

  //Clones the corporate creator field on the 'new' form.
  $('#add_another_corporate_creator').click(function() {
    var cloned = $('div.corporate_creator').first().clone();
    var remove_button = "<button type='button' class='remove_corporate_creator'>Remove Corporate Creator</button>";

    cloned.find('label').text('Additional corporate contributor');
    cloned.find('input:text').val('');
    cloned.find('input:text').attr('required', 'true');

    $('div.corporate_creator').last().after(cloned);
    $('div.corporate_creator').find('input:text').last().after(remove_button);
  });

  //Removes the corporate creator field for this button on the 'new' form. 
  $('form').on('click', '.remove_corporate_creator', function() {
    var target = $(event.target);
    target.parents('.corporate_creator').remove();
  });

  //Clones the keyword field on the 'new' form.
  $('#add_another_keyword').click(function () {
    var cloned = $('div.keyword').first().clone();
    var remove_button = "<button type='button' class='remove_keyword'>Remove Keyword</button>"; 

    cloned.find('label').text('Additional keyword'); 
    cloned.find('input:text').val('');
    cloned.find('input:text').attr('required', 'true');

    $('div.keyword').last().after(cloned);
    $('div.keyword').find('input:text').last().after(remove_button);
  });

  //Removes the keyword field for this button on the 'new' form. 
  $('form').on('click', '.remove_keyword', function(){
    var target = $(event.target);
    target.parents('.keyword').remove();
  });

  //Clones and updates the perm field on the 'new' form.
  $('#add_another_permission').click(function (){

    var new_permission = $('.permission').first().clone();
    var new_permission_count = $('.permission').length;

    var identity_type_id = new_permission_count + '_nu_collection_identity_type';
    var identity_type_name = 'nu_collection[permissions][permissions' + new_permission_count + '][identity_type]';

    var identity_id = new_permission_count + '_nu_collection_identity';
    var identity_name = 'nu_collection[permissions][permissions' + new_permission_count + '][identity]';

    var permission_type_id = new_permission_count + '_nu_collection_permission_type'; 
    var permission_type_name = 'nu_collection[permissions][permissions' + new_permission_count + '][permission_type]';

    var remove_button = "<button type='button' class='remove_permission'>Remove Permission</button>"; 

    //Update the label and dropdown for choosing between group/person level permissions.
    new_permission.find('label').eq(0).attr('for', identity_type_id);
    new_permission.find('select').eq(0).attr('id', identity_type_id); 
    new_permission.find('select').eq(0).attr('name', identity_type_name); 

    //Update the label and textfield for entering group name or user NUID.  
    new_permission.find('label').eq(1).attr('for', identity_id); 
    new_permission.find('input:text').attr('id', identity_id); 
    new_permission.find('input:text').attr('name', identity_name); 

    //Update the label and dropdown for choosing between read/edit permission levels.
    new_permission.find('label').eq(2).attr('for', permission_type_id); 
    new_permission.find('select').eq(1).attr('id', permission_type_id); 
    new_permission.find('select').eq(1).attr('name', permission_type_name); 

    //Clear all form elements before outputting 
    new_permission.find('select').removeAttr('selected'); 
    new_permission.find('input:text').val('');
    new_permission.find('input:text').attr('required', 'true');


    $('.permission').last().after(new_permission);
    $('.permission').find('select').last().after(remove_button);   
  });

  $('form').on('click', '.remove_permission', function() {
    var target = $(event.target);
    target.parents('.permission').remove();
  });
});