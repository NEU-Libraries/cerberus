true
(($) ->
  $.fn.addBsAlert = (options) ->
    settings = $.extend(
      classes: 'alert'
      strong: 'Alert'
      text: 'Something is up!'
    , options)
    alert = $('<div />')
    alert.addClass settings.classes
    alert.append($('<button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>')).append $('<strong>' + settings.strong + '</strong><span> ' + settings.text + ' </span>')
    $(this).after alert

  $.fn.addFormFields = (options) ->

    # applying settings for the function.
    count = 0
    settings = $.extend(
      target: null
      titleText: 'Remove Element'
      removeButton: $('<button type="button" class="btn btn-danger" data-target=".to-remove" data-delete ><span class="icon-remove"></span><span class="sr-only">Remove fields</span></button>')
    , options)

    #adding some error handling here.
    unless settings.target?
      console.log 'must provide target: ' + this
      return

    #adding the click event to handle adding form fields.
    @click ->
      $cloned = settings.target.first().clone()
      $cloned.val(  ->
        return ''
      )
      $cloned.addClass 'to-remove'
      lastInputParentDiv = $cloned.find('div:last-child')

      if lastInputParentDiv.length == 0 then $cloned.addClass 'input-append'; $cloned.css("display","block");
      else lastInputParentDiv.addClass 'input-append'

      # .css("display","block");

      $removeButton = settings.removeButton.clone().attr('title', settings.titleText)


      #label the cloned fields.
      $cloned.find('label').each ->
        forId = $(this).attr('for') + count
        $(this).attr 'for', forId
        $(this).next('input, select').val('').attr 'id', forId
        return


      #add the cloned elements.
      $( @ ).before $cloned
      lastInput = $cloned.find('input, select').last()

      lastInput.removeClass (index, css) ->
        (css.match(/(^|\s)span\S+/g) or []).join " "

      if lastInputParentDiv.length != 0 then lastInput.addClass 'span10'
      else lastInput.addClass 'span11'

      lastInput.after $removeButton.tooltip()

      if lastInput.is( "select" ) then lastInput.addClass 'selectpicker'
      if lastInput.is( "select" ) then lastInput.selectpicker()

      count++
      return

    return
) jQuery
