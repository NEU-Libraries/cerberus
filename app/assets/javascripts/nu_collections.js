//Handles spawning new permission related form elements on the nu_collections/new page.  
$(document).ready(function () {
  'use strict';

  $('#add_another_permission').click(function (){

    var new_permission = $('.permission_element').last().clone();
    var new_permission_count = $('.permission_element').length;

    var identity_type_id = new_permission_count + '_nu_collection_identity_type';
    var identity_type_name = 'nu_collection[permissions' + new_permission_count + '][identity_type]';

    var identity_id = new_permission_count + '_nu_collection_identity';
    var identity_name = 'nu_collection[permissions' + new_permission_count + '][identity]';

    var permission_type_id = new_permission_count + '_nu_collection_permission_type'; 
    var permission_type_name = 'nu_collection[permissions' + new_permission_count + '][permission_type]';

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


    $('.permission_element').last().after(new_permission);  
  });
});