
# global jQuery: false 

# jshint strict: true 

# global _gaq: false 
'use strict'
(($) ->
  $(window).ready ->
    
    ###
    Handles the an jQuery event object.
    @param  {object}   jQuery Event Object
    @return {string}   The status of the push.
    ###
    sendEvent = (event) ->
      data = event.data or {}
      eventArray = ['_trackEvent'] #['_trackEvent', 'category', 'action', 'opt_label', opt_value, opt_noninteraction
      eventArray.push data.category or 'default event category'
      eventArray.push data.action or 'default event action'
      eventArray.push data.label or 'default event label'
      eventArray.push data.value or 1
      eventArray.push data.nonInteractive or false
      _gaq.push eventArray

    
    ###
    Extends the simple send event function to get the pid of the item
    ###
    sendDownloadEvent = (event) ->
      event.data.label = $(this).closest('.drs-item').data('drsitem')
      sendEvent event
      return

    
    ###
    Send links ending with the PID to Google Analytics for reporting.
    ###
    $('a[href*="/downloads/"]').on 'click',
      category: 'Download'
      action: 'Content Download'
      value: 1
      nonInteractive: true
    , sendDownloadEvent
    
    ###
    sendPageView for full items
    @param  {object} element DOM Target to look for
    @return {boolean}        Sent or not
    ###
    sendPageView = (element) ->
      $e = $(element)
      itemPid = ''
      if $e.length > 0
        itemPid = $e.data('drsitem')
        status = _gaq.push([
          '_trackEvent'
          'View'
          'Full Item View'
          itemPid
          1
        ])
        status
      else
        false

    return

  return
)(jQuery)
