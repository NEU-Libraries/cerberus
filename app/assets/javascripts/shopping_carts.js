$(document).ready(function () {
  'use strict';

  var interval_id = null; 

  // If we're on the shopping_cart/download page, start polling 
  // the server.
  if($("#sc_download_page").length > 0) {
    if ($('#button_slot').is(':empty')){
      interval_id = setInterval(poll_server(), 3000);
      console.log("Interval id is" + interval_id);
    }
  }


  // 
  function poll_server() {
    console.log("From poll server, interval id is" + interval_id);

    if ($('#button_slot').is(':empty')){
      console.log("Rendering get script call");
      $.getScript('/shopping_cart/download.js');
    } else {
      console.log("Cleaning interval id " + interval_id + " out.");
      clearInterval(interval_id);
    }
  }
});