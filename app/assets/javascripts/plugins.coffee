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
      removeButton: $('<button type="button" class="btn btn-danger"><i class="icon-remove"></i></button>')
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
      $cloned.addClass 'input-append'
      $removeButton = settings.removeButton.clone().attr('title', settings.titleText)
      $removeButton.click ->
        $cloned.remove()
        return

      
      #label the cloned fields.
      $cloned.find('label').each ->
        forId = $(this).attr('for') + count
        $(this).attr 'for', forId
        $(this).next('input, select').val('').attr 'id', forId
        return

      
      #add the cloned elements.
      $( @ ).before $cloned
      lastInput = $cloned.find('input, select').last()
      lastInput.after $removeButton.tooltip()
      count++
      return

    return
  $.fn.deleteFields = (options) ->
    
    $e = $(@)

    settings = $.extend(
      'target' : $e.data('target') || null 
      'confirm' : $e.data('confirm') || false
    , options
    )

    if settings.target? then throw 'No target provided'
      
    $target = $( settings.target )

    destroy = ( target ) ->
      $e.off('click')

      target.remove()
      $e.remove()
    confirmOrDesctroy = (e) ->
      if e.data.confrim is true
        confirmation = confrim('Are you sure you want to delete this field')
      else
        confirmation = true
      if confirmation
        destroy( e.data.target )
    init = ( $e ) -> 
      $e.on('click', settings, confirmOrDesctroy(e) )

  $('*[data-delete]').deleteFields(
    confirm: true
  )
) jQuery
