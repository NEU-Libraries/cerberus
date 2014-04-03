true

# global jQuery: false

# jshint strict: true

# global _gaq: false

'use_strict'
(($) ->
  $(document).ready ->

    #Poll the show download page for changes every three seconds.
    addDownloadLink = ->
      if $('#display_download_link').is(':empty')
        # fetch the comp id, figure out who to ping
        comp_id = $('#data').attr('data-comp-id')
        $.getScript '/sets/' + comp_id + '/ping.js'
      else
        clearInterval sets_interval_id
      return

    'use strict'
    sets_interval_id = null
    if $('#display_download_link').length > 0
      if $('#display_download_link').is(':empty')
        sets_interval_id = setInterval(addDownloadLink(), 3000)
    return
)(jQuery)
