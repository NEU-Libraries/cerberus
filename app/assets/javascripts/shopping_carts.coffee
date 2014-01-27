true
# global jQuery: false 

# jshint strict: true 

# global _gaq: false 
'use strict'
(($) ->
  $(document).ready ->
    
    # If we're on the shopping_cart/download page, start polling 
    # the server. 
    poll_server = ->
      console.log 'From poll server, interval id is' + interval_id
      if $('#button_slot').is(':empty')
        console.log 'Rendering get script call'
        $.getScript '/shopping_cart/download.js'
      else
        console.log 'Cleaning interval id ' + interval_id + ' out.'
        clearInterval interval_id
      return
    'use strict'
    interval_id = null
    if $('#sc_download_page').length > 0
      if $('#button_slot').is(':empty')
        interval_id = setInterval(poll_server(), 3000)
        console.log 'Interval id is' + interval_id
    return

)(jQuery)