$("#admin_employee_autocomplete").autocomplete({
    source: employees_for_autocomplete,
    select: function(e, ui) {
        e.preventDefault() // <--- Prevent the value from being inserted.
        $("#admin_employee").val(ui.item.value);
        $(this).val(ui.item.label);
    },
    focus: function( e, ui ) {
      e.preventDefault() // <--- Prevent the value from being inserted.
    }
});

$( "#admin_employee_autocomplete" ).attr('autocomplete', 'on');
