true
'use strict'

# jshint undef: true, unused: true 

#global $:false 

#global Modernizr 

#global ui 

#global picturefill 
$(document).ready ->
  drsApp = (->
    init = (settings) ->
      drsApp.config =
        $drsBootstrapSelect: $('select.bs-select')
        $addToSetLink: $('#addToSet')
        breadCrumbMenuContent: $('#addToSetLinks').html()
        fitTextTarget: $('.fit-text')

      
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
      handleDrsItem $('.drs-item[data-drsitem]:not(.drs-item-full)')
      return

    
    ###
    Provides the breadcrumb popover menu for adding collections or new items to the application.
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

    
    # var storeData = function ( data ){
    #   var storage = window.localStorage;
    #   var storedData;
    #   if ( storage.key( 'drsApp' )){
    #     storedData = storage.getItem( 'drsApp' );
    #     storedData = JSON.parse( storeData );
    #     data = $.merge( storedData, data );
    
    #   }
    #   storage.setItem( 'drsApp' , JSON.stringify ( data ) );
    # };
    
    # fetchData = function( ){
    
    #   var data = {};
    
    #   if( window.localStorage ){
    #     if ( window.localStorage.('dr')){
    #       data JSON.parse( window.localStorage.getItem('drsApp') )
    #     }
    #   }
    
    # };
    # var getData = function ( key ){
    #    var storage = window.localStorage;
    #    var storedData = JSON.parse( storage.getItem ;
    
    # };
    gridOrListSwitch = (dataTarget) ->
      switch dataTarget
        when 'drs-items-list'
          'list'
        when 'drs-items-grid'
          'grid'
        else
          throw 'dataTarget wasn\'t given'
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

    handleDrsItem = (element) ->
      $(element).on 'click', (event) ->
        target = $(event.target)
        parent = $(this).closest('.drs-items')
        if target.is('a, a*, button, button * , input, input *,  select, select *, textarea')
          event.stopPropagation()
        #Change the action to only fire on the items-grid
        else if parent.data('toggle') is 'drs-view'
          
          #remove add the class to the target.
          if $(this).hasClass('active')
            parent.find('.drs-item').removeClass 'active'
          else
            parent.find('.drs-item').removeClass 'active'
            $(this).addClass 'active'
          pictureActive $(this).find('[data-picture]')
        else if parent.hasClass('drs-items-grid')
          window.location.assign $(this).data('href')  if $(this).data('href').length > 4 and not $(this).hasClass('drs-item-full')
        return

      return

    pictureActive = (element) ->
      $e = $(element)
      $src = $e.find('[data-src]')
      $src.each ->
        $this = $(this)
        $this.attr 'data-media': ' '  unless $this.attr('data-media')
        target = $this.attr('data-active')
        active = $this.attr('data-media')
        $this.attr
          'data-media': target
          'data-active': active

        return

      picturefill.apply()
      return

    cloneGrid = (t, parent) ->
      console.log $('.drs-item').length
      $t = $(t)
      $(parent).find('.drs-item.jumbotron').remove()
      if $t.hasClass('active')
        $clone = $t.clone()
        $clone.addClass 'jumbotron'
        $t.append $clone
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

    
    # these are the public API
    init: init
    addToComplationLink: addToComplationLink
    newCompilationForm: newCompilationForm
    compilationsModal: compilationsModal
  )()
  
  #end drsApp module;
  window.drsApp = drsApp
  drsApp.init updateUserviewPrefBoolean: false
  return

