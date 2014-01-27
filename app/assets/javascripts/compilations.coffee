true
$(document).ready ->
  
  #Poll the show download page for changes every three seconds. 
  addDownloadLink = ->
    comp_id = $('#data').attr('data-comp-id')
    $.getScript '/compilations/' + comp_id + '/ping.js?comp_id=' + comp_id
    return
  'use strict'
  setInterval addDownloadLink, 3000  if $('#download_link').length is 0  if $('#display_download_link').length > 0
  return

