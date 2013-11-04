if ($("#admin_community_autocomplete").length > 0) { 
  $("#admin_community_autocomplete").autocomplete({
      source: communities_for_employee_autocomplete,
      select: function(e, ui) {
          e.preventDefault() // <--- Prevent the value from being inserted.
          $("#admin_community").val(ui.item.value);
          $(this).val(ui.item.label);
      },
      focus: function( e, ui ) {
        e.preventDefault() // <--- Prevent the value from being inserted.
      }
  });

  $( "#admin_community_autocomplete" ).attr('autocomplete', 'on');
}