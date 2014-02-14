'use strict'

# jshint undef: true, unused: true


# global $:false

# global Modernizr

# global ui

#global picturefill
$(document).ready ->
  drsApp = (->
    init = (settings) ->
      drsApp.config =
        $drsBootstrapSelect: $('select.bs-select')
        $addToSetLink: $('#addToSet')
        breadCrumbMenuContent: $('#addToSetLinks').html()
        fitTextTarget: $('.fit-text')
        removeFormFields:
          listener : false

      # allow overriding the default config
      $.extend drsApp.config, settings
      setup()
      return

    setup = ->
      nuCollectionsPage()
      breadCrumbMenu()
      handleFitText()
      tooltipSetup()
      handleRequiredInputs()
      ellipsisExpand()
      drsToggleView()
      handleDrsCommunities()
      handleDrsAdminCommunities()
      handleCommunitiesAdminAutoComplete()
      toggleShoppingCart $('*[data-shoppingcart]')
      singleUploadTermsOfService()
      removeFormFields()
      return


    ###
    Provides the breadcrumb popover menu for adding collections
    or new items to the application.
    ###
    breadCrumbMenu = ->
      drsApp.config.$addToSetLink.popover(
        html: true
        content: drsApp.config.breadCrumbMenuContent
      ).on('shown', ->
        $(this).parent('li').addClass 'active'
        return
      ).on 'hide', ->
        $(this).parent('li').removeClass 'active'
        return

      return

    addToComplationLink = (e) ->
      e.on('ajax:success', ->
        delta = $(this).data('method')
        switch delta
          when 'post'
            $(this).text($(this).text().replace('Add to', 'Remove from')).data('method', 'delete').removeClass('btn-success add-to-compilation').addClass 'btn-danger remove-from-compilation'
          when 'delete'
            $(this).data('method', 'post').text($(this).text().replace('Remove from', 'Add to')).addClass('btn-success add-to-compilation').removeClass 'btn-danger remove-from-compilation'
          else
            console.log 'ajax successful, but not sure what to do!'
      ).on 'ajax:error', ->
        $(this).closest('.modal').modal 'hide'
        $('.breadcrumb').addBsAlert
          classes: 'alert alert-danger'
          strong: 'Error,'
          text: 'Something went wrong, please reload the page and try again.'

        return

      return
    # Builds and requests the new compilation form for the ajax request

    newCompilationForm = ->
      $('#new_compilation').on('ajax:success', ->
        $(this).closest('.modal').modal 'hide'
        $('.breadcrumb').addBsAlert
          classes: 'alert alert-success'
          strong: 'Success!'
          text: 'You created a new compilation!'
      ).on 'ajax:error', ->
        $(this).closest('.modal').modal 'hide'
        $('.breadcrumb').addBsAlert
          classes: 'alert alert-danger'
          strong: 'Error,'
          text: 'Something went wrong, please reload the page and try again.'

        return

      return
    ###
    Handles the compilation modal object for the page
    ###
    compilationsModal = (e) ->
      $modal = $('#ajax-modal')
      $modal.empty().append(e).modal 'show'
      $modal.on 'hidden', ->
        $(this).empty()
        return

      drsApp.addToComplationLink $('.btn-compilation')
      drsApp.newCompilationForm()
      return


    ###
    Checks the dom to see if the plugin target is there and then loads it with Modernizr
    ###
    handleFitText = ->
      if drsApp.config.fitTextTarget.length > 0 and window.Modernizr
        Modernizr.load
          load: '//cdnjs.cloudflare.com/ajax/libs/FitText.js/1.1/jquery.fittext.min.js'
          complete: ->
            Modernizr.load '/assets/polyfills/FitText-js/jquery.fittext.js'  unless $.fitText
            drsApp.config.fitTextTarget.fitText()
            return

      return


    ###
    Tooltip Setup
    ###
    tooltipSetup = ->
      $('body').tooltip selector: 'a[data-toggle=tooltip]'
      return


    ###
    Builds interaction to inputs with [required="required"] to make sure that the user fills it out.
    ###
    handleRequiredInputs = ->

      #Query for inputs textareas and selects with require
      targets = $('input, textarea, select').filter('[required="required"]')

      #Construct the tooltips for inputs that need to be filled still.
      addTooltip = (e) ->
        $(e).tooltip title: 'Required'


      #cycle through each function.
      targets.each (index, el) ->
        id = $(el).attr('id')

        #add the required class.
        $('label[for="' + id + '"]').addClass 'required-label'

        # Check the element to figure out if we still need the tooltip or not.
        $(el).on 'focus hover click change keypress', ->
          if $(this).val().length > 0
            $(this).tooltip 'destroy'
          else
            addTooltip this
          return

        return

      return


    ###
    Looks for the datatoggle
    @return {[type]} [description]
    ###
    ellipsisExpand = ->
      $toggleLink = $('*[data-toggle="ellipsis"]')

      #look for the target and toggle classes on that element.
      toggleState = (event) ->

        #stop the event from triggering other reations
        event.preventDefault()
        event.stopPropagation()
        $target = (if $(this).attr('href').length > 0 then $($(this).attr('href')) else $($(this).data('target')))
        if $target.length > 0
          $target = $target.find('.ellipsis')  unless $target.hasClass('ellipsis')
          $target.toggleClass 'in'
          $(this).children('i').toggleClass('icon-expand-alt').toggleClass 'icon-collapse-alt'
        else
          console.log 'Invalid target specified for drsApp.ellipsisExpand', $target
        return

      $toggleLink.on 'click', toggleState
      return


    ###
    drsToggleView adds an event listener to a div containing two buttons that should toggle a class on an conainter div with drs-items to change their display.
    ###
    drsToggleView = ->
      handleClick = (event) ->
        event.preventDefault()
        event.stopPropagation()
        toggleContainer = $(this).closest('*[data-container]')
        container = $(toggleContainer.data('container'))
        desiredClass = $(this).data('target')
        if container.hasClass(desiredClass)
          event.preventDefault()
        else
          container.find('.drs-item').removeClass 'active'
          toggleContainer.find('a, button').removeClass 'active'
          $(this).addClass 'active'
          if desiredClass is 'drs-items-grid'
            container.removeClass('drs-items-list').addClass 'drs-items-grid'
          else
            container.removeClass('drs-items-grid').addClass 'drs-items-list'
          if $('body').data('user') > 0
            updateUserViewPref $(this)
          else
            null
        return

      $('[data-toggle="drs-item-views-radio"]').on 'click', 'a , button', handleClick
      return

<<<<<<< HEAD


=======
    # Utility Function for what to switch to
    #
>>>>>>> develop
    gridOrListSwitch = (dataTarget) ->
      switch dataTarget
        when 'drs-items-list'
          'list'
        when 'drs-items-grid'
          'grid'
        else
          throw new DrsAppError 'dataTarget wasn\'t given', dataTarget
      return


    ###
    updateUserViewPref
    @TODO
    ###
    updateUserViewPref = (element) ->
      if drsApp.config.updateUserviewPrefBoolean
        target = element.data('target')
        userId = $('body').data('user') or 5
        queryString = '/users/' + userId
        $.ajax
          url: queryString
          type: 'post'
          data:
            view_pref: gridOrListSwitch(target)

          complete: (jqXHR, textStatus) ->

      return


    #Handles spawning new permission related form elements on the nu_collections/new page.
    nuCollectionsPage = ->

      #Add a datepicker to the date of issuance field.
      $('#date-issued, #embargo-date').datepicker
        todayBtn: true
        todayHighlight: true
        clearBtn: true


      # Adding the form fields behavior to the buttons on the nu collections.
      $('#add_another_personal_creator').addFormFields
        target: $('div.personal_creator')
        titleText: 'Remove Personal Creator'

      $('#add_another_corporate_creator').addFormFields
        target: $('div.corporate_creator')
        titleText: 'Remove Corporate Creator'

      $('#add_another_keyword').addFormFields
        target: $('div.keyword')
        titleText: 'Remove keyword'

      $('#add_another_permission').addFormFields
        target: $('div.permission')
        titleText: 'Remove permission'

      return

    handleDrsCommunities = ->
      if $('#community_autocomplete').length > 0
        $('#community_autocomplete').autocomplete
          source: communities_for_autocomplete
          select: (e, ui) ->
            e.preventDefault() # <--- Prevent the value from being inserted.
            $('#community_parent').val ui.item.value
            $(this).val ui.item.label
            return

          focus: (e, ui) ->
            e.preventDefault() # <--- Prevent the value from being inserted.
            return

        $('#community_autocomplete').attr 'autocomplete', 'on'
      return

    handleDrsAdminCommunities = ->
      if $('#admin_community_autocomplete').length > 0
        $('#admin_community_autocomplete').autocomplete
          source: communities_for_employee_autocomplete
          select: (e, ui) ->
            e.preventDefault() # <--- Prevent the value from being inserted.
            $('#admin_community').val ui.item.value
            $(this).val ui.item.label
            return

          focus: (e) ->
            e.preventDefault() # <--- Prevent the value from being inserted.
            return

        $('#admin_community_autocomplete').attr 'autocomplete', 'on'
      return

    handleCommunitiesAdminAutoComplete = ->
      if $('#admin_employee_autocomplete').length > 0
        $('#admin_employee_autocomplete').autocomplete
          source: employees_for_autocomplete
          select: (e, ui) ->
            e.preventDefault() # <--- Prevent the value from being inserted.
            $('#admin_employee').val ui.item.value
            $(this).val ui.item.label
            return

          focus: (e) ->
            e.preventDefault() # <--- Prevent the value from being inserted.
            return

        $('#admin_employee_autocomplete').attr 'autocomplete', 'on'
      return


    ###
    Listener function for shopping cart links with a fall back on failure to reload the page.
    ###
    toggleShoppingCart = (e) ->
      $e = $(e)
      if $e.length > 0
        $e.on('ajax:beforeSend', ->
          $(this).attr 'data-shoppingcart', 'replace'
          $(this).tooltip 'destroy'
          return
        ).on('ajax:failure', ->
          window.location.reload()
          return
        ).on 'ajax:success', ->
          toggleShoppingCart drsApp.$new
          $(this).replaceWith drsApp.$new
          drsApp.$new = null
          return

      return


    ###
    Enable the the submit and form submit on the upload field only after the user agrees to the terms of service
    ###

    singleUploadTermsOfService = ->
      if $('#singleFileUploadForm').length > 0
        $(a)


    ###
    Show model using the #ajax-modal on created at the bottom of every page.
    ###
    initModal = ( heading = "Modal", body ="Hello World", footer = false,  show = true ) ->
      t = $('#ajax-modal')
      t.find('#ajax-modal-heading').text(heading)
      t.find('#ajax-modal-body').html(body)
      if footer
        t.find('#ajax-modal-footer').html(footer)
      else
        t.find('#ajax-modal-footer').hide()
      t.modal({
        'show' : show
        })
      clear = ->
        t.find('#ajax-modal-heading').text('')
        t.find('#ajax-modal-body').html('')
        t.find('#ajax-modal-footer').html('').css('display', 'block')
        t.off('hidden')
      reloadWindow = ->
        window.location.reload()
      listenForAjax = ( element ) ->
        $( element ).on('ajax:complete', reloadWindow )

      # We shouldn't need to do this but there isn't a great way of updating the DOM and keeping the data in sync with the app.
      hanldleRemoteLinks = ->
        remoteLinks = t.find( 'a[data-remote]' )
        listenForAjax link for link in remoteLinks
      hanldleRemoteLinks()
      t.on('hidden', clear)


    # Handle remove form field buttons click
    #
    #  <div class="control-group" id="controlGroup1">
    #    <label for="">email</label>
    #    <input type="email" id="email-field">
    #    <button type="button" data-delete data-target=".control-group">Delete Field</button>
    #  </div>
    #  This markup will cause the removal of the contain div, so you would need to place the element
    #  with the markup in a container element, or the function is smart enough to find a specific jQuery selector and delete that selector and itself.
    #  General yet specific


    removeFormFields = ( ) ->

      handleClick = (e) ->
          $el = $(@)
          e.preventDefault()
          removeSelector = $el.data('target')
          unless removeSelector?
             removeSelector = $el.attr('href')

          # This is vague to allow class selectors of containing divs
          $remove = $el.closest( removeSelector ).first()

          #if this remove variable is still null then let's make sure it is specific to only one item
          if $remove.length == 0
            $remove = if  $( removeSelector ).length is 1 then $( removeSelector ) else null

          if $remove?
            # make sure to remove the element itself
            $el.remove()
            $remove.empty().remove()
          else
            throw new DrsAppError "Couldn't find specific target or parent element to remove." , removeSelector
      if drsApp.config.removeFormFields.listener
        $('*[data-delete ]').on('click', handleClick )
      else
        $('body').on('click', '*[data-delete]' , handleClick )


    DrsAppError = ( message = 'Error:', value = null ) ->
      @.message = message
      @.value = value
      @.toString = ->
        message + '.  Value:' + value

    # these are the public API

    init: init
    addToComplationLink: addToComplationLink
    newCompilationForm: newCompilationForm
    compilationsModal: compilationsModal
    initModal: initModal
  )()

  #end drsApp module;
  window.drsApp = drsApp
  drsApp.init(
    updateUserviewPrefBoolean: false
  )
