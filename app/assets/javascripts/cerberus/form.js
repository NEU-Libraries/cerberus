$(function()
{
    $(document).on('click', '.reset', function(e)
    {
        e.preventDefault();
        $(':input').not(':button, :submit, :reset, :hidden').removeAttr('checked').removeAttr('selected').not('‌​:checkbox, :radio, select').val('');
    });
});

$(function()
{
    $(document).on('click', '.btn-add', function(e)
    {
        e.preventDefault();

        var hr = document.createElement("hr");

        var controlForm = $('#provideMetadataForm'),
            currentEntry = $(this).parents('.row:first'),
            newEntry = $(currentEntry.clone().find('.dropdown-toggle, .dropdown-menu').remove().end()).insertAfter(currentEntry);
            newEntry.find(':input').not(':button, :submit, :reset, :hidden').removeAttr('checked').removeAttr('selected').not('‌​:checkbox, :radio, select').val('');

        $(hr).insertAfter(currentEntry);

        $('.selectpicker').selectpicker({});

        newEntry.find('.btn-add:last')
            .removeClass('btn-add').addClass('btn-remove')
            .removeClass('btn-success').addClass('btn-danger')
            .html('<span class="glyphicon glyphicon-minus"></span>');
    }).on('click', '.btn-remove', function(e)
    {
      $(this).parents('.row').first().prev().remove();
      $(this).parents('.row').first().remove();
      e.preventDefault();
      return false;
  });
});
