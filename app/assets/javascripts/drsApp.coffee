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
        $addToSetLink: $('*[data-add-to-set]')
        breadCrumbMenuContent: $('#addToSetLinks').html()
        fitTextTarget: $('.fit-text')
        removeFormFields:
          listener : false


      # allow overriding the default config
      $.extend drsApp.config, settings
      setup()
      return

    setup = ->
      CollectionsPage()
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
      removeFormFields()
      imageMetadataPartial()
      datePartial()
      titlePartial()
      removeFromCartToggle()
      multiModalToggle()
      triggerCompilationDownload()
      triggerCartDownload()
      parseTitle()
      groupPermissionDisplayWhenPrivate()
      handleGroupPermissionAdd()
      handleGroupPermissionRemoval()
      doSelectSubmit()

      return

    triggerCartDownload = ->
      x =
        download_interval_id: false
        addDownloadLink: ->
          if $('#button_slot').is(':empty')
            $.getScript '/download_queue/download.js'
          else
            clearInterval(x.download_interval_id)
          return

      if $('#sc_download_page').length > 0
        if $('#button_slot').is(':empty')
          x.download_interval_id = setInterval(x.addDownloadLink, 3000)

    triggerCompilationDownload = ->
      x =
        download_interval_id: false,
        addDownloadLink: ->
          if $('#display_download_link').is(':empty')
            comp_id = $('#data').attr('data-comp-id')
            $.getScript "/sets/#{comp_id}/ping.js"
          else
            clearInterval(x.download_interval_id)
          return

      if $('#display_download_link').length > 0
        if $('#display_download_link').is(':empty')
          x.download_interval_id = setInterval(x.addDownloadLink, 3000)


    removeFromCartToggle = ->
      $('.cart-multi-modal').click ->

        path  = $(this).data('delete-path')

        $('.modal-footer a').attr("href", path)
        return

    # On pages that should have multiple item deletion modals,
    # this method is called on click to modify the one such modal
    # rendered on that page
    multiModalToggle = ->
      $('.multi-modal').click ->
        title = $(this).data('title')
        path  = $(this).data('delete-path')

        header_str = "Confirm deleting #{title}"
        str = "Are you sure you want to delete #{title} and all of the items it
               contains?  We cannot undo this action!"

        $('#deleteItemModalLabel').text(header_str)
        $('.modal-body p').text(str)
        $('.modal-footer a').attr("href", path)
        return

    parseTitle = ->

      if $("#full_title").length > 0
        nonSort = ''
        fullTitle = $('#full_title').val().toLowerCase()

        if fullTitle.indexOf('the ') is 0
          shortTitle = fullTitle.split("the ")[1]
          nonSort = "The"
        else if fullTitle.indexOf('an ') is 0
          shortTitle = fullTitle.split("an ")[1]
          nonSort = "An"
        else if fullTitle.indexOf('a ') is 0
          shortTitle = fullTitle.split("a ")[1]
          nonSort = "A"

        if nonSort != ''
          $("#core_file_non_sort").val nonSort
          $("#core_file_title").val shortTitle
        else
          $("#core_file_non_sort").val ""
          $("#core_file_title").val $("#full_title").val().trim()
        return

    titlePartial = ->
      $("#full_title").bind "change paste keyup", ->
        parseTitle()
      return

    doSelectSubmit = ->
      $(doSelectSubmit.selector).each ->
        select = $(this)
        select.bind "change", ->
          select.closest("form").submit()
          false
        return
      return

    doSelectSubmit.selector = "form select#sort, form select#per_page"

    datePartial = ->
      if $('#core_file_date').length > 0
        $().dateSelectBoxes $("#doiMonth"), $("#doiDay"), $("#doiYear"), true

        try
          $("#doiYear").val $("#core_file_date").val().split("-")[0]
        catch error

        try
          $("#doiMonth").val $("#core_file_date").val().split("-")[1].replace(/^0*/, "")
        catch error

        try
          $("#doiDay").val $("#core_file_date").val().split("-")[2].replace(/^0*/, "")
        catch error

        if $("#doiMonth").val() == ""
          $("#doiDay").val $("#doiDay option:first").val()
          $("#doiDay").prop("disabled", true)
        else
          $("#doiDay").prop("disabled", false)

      $("#doiDay").change ->
        combineDate()
        return

      $("#doiMonth").change ->
        if $("#doiMonth").val() == ""
          $("#doiDay").val $("#doiDay option:first").val()
          $("#doiDay").prop("disabled", true)
        else
          $("#doiDay").prop("disabled", false)

        combineDate()
        return

      $("#doiYear").change ->
        combineDate()
        return

      return

    combineDate = ->
      $("#core_file_date").val $("#doiYear").val() + "-" + String("0" + $("#doiMonth").val()).slice(-2) + "-" + String("0" + $("#doiDay").val()).slice(-2)
      $("#core_file_date").val $("#core_file_date").val().replace(/-+$/, "")
      $("#core_file_date").val $("#core_file_date").val().replace(/-[0]$/, "").replace(/-[0]$/, "")
      return


    enforceSizes = ->
      if parseInt($("#small_image_size").val()) >= parseInt($("input.slider.small").attr("data-slider-max"))
        $("#small_image_size").val parseInt($("input.slider.small").attr("data-slider-max")) - 2
        $("input.slider.small").slider "setValue", parseInt($("input.slider.small").attr("data-slider-max")) - 2

      if parseInt($("#medium_image_size").val()) >= parseInt($("input.slider.medium").attr("data-slider-max"))
        $("#medium_image_size").val parseInt($("input.slider.medium").attr("data-slider-max")) - 1
        $("input.slider.medium").slider "setValue", parseInt($("input.slider.medium").attr("data-slider-max")) - 1

      if parseInt($("#large_image_size").val()) > parseInt($("input.slider.large").attr("data-slider-max"))
        $("#large_image_size").val parseInt($("input.slider.large").attr("data-slider-max"))
        $("input.slider.large").slider "setValue", parseInt($("input.slider.large").attr("data-slider-max"))

      if $("input.slider.small").slider("getValue") > $("input.slider.medium").slider("getValue")
        if not $("#small_image_size").prop("disabled") and not $("#medium_image_size").prop("disabled")
          $("input.slider.medium").slider "setValue", $("input.slider.small").slider("getValue") + 1
          $("#medium_image_size").val $("input.slider.small").slider("getValue") + 1

      if $("input.slider.medium").slider("getValue") < $("input.slider.small").slider("getValue")
        if not $("#small_image_size").prop("disabled") and not $("#medium_image_size").prop("disabled")
          $("input.slider.small").slider "setValue", $("input.slider.medium").slider("getValue") - 1
          $("#small_image_size").val $("input.slider.medium").slider("getValue") - 1

      if $("input.slider.medium").slider("getValue") > $("input.slider.large").slider("getValue")
        if not $("#large_image_size").prop("disabled") and not $("#medium_image_size").prop("disabled")
          $("input.slider.large").slider "setValue", $("input.slider.medium").slider("getValue") + 1
          $("#large_image_size").val $("input.slider.medium").slider("getValue") + 1

      if $("input.slider.large").slider("getValue") < $("input.slider.medium").slider("getValue")
        if not $("#large_image_size").prop("disabled") and not $("#medium_image_size").prop("disabled")
          $("input.slider.medium").slider "setValue", $("input.slider.large").slider("getValue") - 1
          $("#medium_image_size").val $("input.slider.large").slider("getValue") - 1

      return

    imageMetadataPartial = ->
      if $('input.slider.small').length > 0
        $("input.slider.small").slider()
        $("input.slider.medium").slider()
        $("input.slider.large").slider()
        $("input#small_slider").on "slide", (slideEvt) ->
          $("#small_image_size").val slideEvt.value
          enforceSizes()
          return

        $("input#medium_slider").on "slide", (slideEvt) ->
          $("#medium_image_size").val slideEvt.value
          enforceSizes()
          return

        $("input#large_slider").on "slide", (slideEvt) ->
          $("#large_image_size").val slideEvt.value
          enforceSizes()
          return

        $("#small_image_size").bind "focus blur", ->
          $("input.slider.small").slider "setValue", parseInt($("#small_image_size").val())
          enforceSizes()
          return

        $("#medium_image_size").bind "focus blur", ->
          $("input.slider.medium").slider "setValue", parseInt($("#medium_image_size").val())
          enforceSizes()
          return

        $("#large_image_size").bind "focus blur", ->
          $("input.slider.large").slider "setValue", parseInt($("#large_image_size").val())
          enforceSizes()
          return

        $("#small_image_checkbox").on "click", ->
          (if $("#small_image_size").prop("disabled") then $("input.slider.small").slider("enable") else $("input.slider.small").slider("disable"))
          $("#small_image_size").prop "disabled", (_, val) ->
            not val
          if $("#small_image_size").prop("disabled") then $("#small_image_size").val 0 ; $("input.slider.small").slider "setValue", 0
          enforceSizes()
          return

        $("#medium_image_checkbox").on "click", ->
          (if $("#medium_image_size").prop("disabled") then $("input.slider.medium").slider("enable") else $("input.slider.medium").slider("disable"))
          $("#medium_image_size").prop "disabled", (_, val) ->
            not val
          if $("#medium_image_size").prop("disabled") then $("#medium_image_size").val 0 ; $("input.slider.medium").slider "setValue", 0
          enforceSizes()
          return

        $("#large_image_checkbox").on "click", ->
          (if $("#large_image_size").prop("disabled") then $("input.slider.large").slider("enable") else $("input.slider.large").slider("disable"))
          $("#large_image_size").prop "disabled", (_, val) ->
            not val
          if $("#large_image_size").prop("disabled") then $("#large_image_size").val 0 ; $("input.slider.large").slider "setValue", 0
          enforceSizes()
          return

      return


    ###
    Provides the breadcrumb popover menu for adding collections
    or new items to the application.
    ###
    breadCrumbMenu = ->
      $link = drsApp.config.$addToSetLink
      $link.popover(
        html: true
        content: drsApp.config.breadCrumbMenuContent,
        trigger: 'focus'
      )

      $link.on('click', 'a', (e) ->
        e.preventDefault()

      )
      if ( $link.parent('breadcrumb').length > 0 )
        $link.on('shown', ->
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
          text: 'You created a new set!'
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
      # event handler for the click event
      handleClick = (event) ->
        # event.preventDefault()
        # event.stopPropagation()

        toggleContainer = $(this).closest('*[data-container]')

        container = $( toggleContainer.data('container') )

        # Find the nearest span element to toggle
        sidebar = toggleContainer.closest( '.drs-sidebar' )

        # Again for the other element
        containerParent = container.closest( '*[class*="span"]' )

        desiredClass = $(this).data('target')

        if container.hasClass(desiredClass)
          event.preventDefault()
        else

          toggleContainer.find('a, button').removeClass 'active'
          $(this).addClass 'active'
          if desiredClass is 'drs-items-grid'
            container.removeClass('drs-items-list').addClass 'drs-items-grid'
            sidebar.removeClass('span3')
            sidebar.addClass('span12')
            containerParent.removeClass('span9')
            containerParent.addClass('span12');
            $('.pane.facets').addClass('span3')
            $('.pane.pagination-info').addClass('span6')
            $('.pane.results-view').addClass('span3')
          else
            container.removeClass('drs-items-grid').addClass 'drs-items-list'
            sidebar.removeClass('span12')
            sidebar.addClass('span3')
            containerParent.removeClass('span12');
            containerParent.addClass('span9')
            $('.pane.facets').removeClass('span3')
            $('.pane.pagination-info').removeClass('span6')
            $('.pane.results-view').removeClass('span3')
        return



      $('[data-toggle="drs-item-views-radio"]').on 'click', 'a , button', handleClick



    # Utility Function for what to switch to
    #

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


    #Handles spawning new permission related form elements on the collections/new page.
    CollectionsPage = ->

      #Add a datepicker to the date of issuance field.
      #$('#date-issued, #embargo-date').datepicker
      $('.datepicker, #embargo-date').datepicker
        todayBtn: true
        todayHighlight: true
        clearBtn: true


      # Adding the form fields behavior to the buttons on the nu collections.
      $('#add_another_personal_creator').addFormFields
        target: $('div.personal_creator:not(.to-remove)')
        titleText: 'Remove Personal Creator'

      $('#add_another_corporate_creator').addFormFields
        target: $('div.corporate_creator:not(.to-remove)')
        titleText: 'Remove Corporate Creator'

      $('#add_another_keyword').addFormFields
        target: $('div.keyword:not(.to-remove)')
        titleText: 'Remove keyword'

      $('#add_another_permission').addFormFields
        target: $('div.permission:not(.to-remove)')
        titleText: 'Remove permission'

      return

    handleDrsCommunities = ->
      if $('#community_autocomplete').length > 0
        $('#community_autocomplete').autocomplete
          source: communities_for_autocomplete
          select: (e, ui) ->
            e.preventDefault()
            $('#community_parent').val ui.item.value
            $(this).val ui.item.label
            return

          focus: (e, ui) ->
            e.preventDefault()
            return

        $('#community_autocomplete').attr 'autocomplete', 'on'
      return

    handleDrsAdminCommunities = ->
      if $('#admin_community_autocomplete').length > 0
        $('#admin_community_autocomplete').autocomplete
          source: communities_for_employee_autocomplete
          select: (e, ui) ->
            e.preventDefault()
            $('#admin_community').val ui.item.value
            $(this).val ui.item.label
            return

          focus: (e, ui) ->
            e.preventDefault()
            $("#admin_community").val ui.item.value
            $("#admin_community_autocomplete").val ui.item.label
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
            $('#admin_employee_autocomplete').val ui.item.label
            $('#admin_employee_name').text "Employee to be added: #{ui.item.name}"
            return

          focus: (e, ui) ->
            e.preventDefault()
            $("#admin_employee").val ui.item.value
            $("#admin_employee_autocomplete").val ui.item.label
            $("#admin_employee_name").text "Employee to be added: #{ui.item.name}"
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
          drsApp.$itemUrl = $(this).attr "href"
          return
        ).on('ajax:failure', ->
          window.location.reload()
          return
        ).on 'ajax:success', ->
          toggleShoppingCart drsApp.$new
          items = $("[href='" + drsApp.$itemUrl + "']")
          items.replaceWith drsApp.$new
          drsApp.$itemUrl = null
          drsApp.$new = null
          items = null
          return

      return


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

    # When we have a group permission panel that only allows
    # setting read permissions, e.g. on the compilations page,
    # we should only show that panel when the item is set to
    # private to avoid confusion
    groupPermissionDisplayWhenPrivate = ->
      if $(".groups.read-only")
        console.log "init"
        groups = $(".groups.read-only").last()
        ele    = $("select[name $= '[mass_permissions]']").last()

        if ele.val() == "public"
          groups.addClass("hidden")
        else if ele.val() == "private"
          groups.removeClass("hidden")

        ele.change ->
          if ele.val() == "public"
            groups.addClass("hidden")
          else if ele.val() == "private"
            groups.removeClass("hidden")
        return


    handleGroupPermissionAdd = ->
      $("#addAnotherGroup").click ->
        html = $(".group").last().clone()
        $("#addAnotherGroup").before(html)
        $(".group").last().removeClass("hidden")
        $(".group").last().find("select").val("read")
        $(".group").last().find("input").val("")
      return

    handleGroupPermissionRemoval = ->
      $(".removeGroupButton").click ->
        val = $(this).parent().children("#groups_name_").val()
        x   = $("#groups_permissionless_groups").val()
        y   = x + " ; #{val}"
        $("#groups_permissionless_groups").val(y)
        return



    ##DrsAppError Class for debugging
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


$('#terms_of_service').on('click change', (e)->
  console.log @, e
)
