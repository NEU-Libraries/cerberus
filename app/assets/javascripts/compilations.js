$(document).ready(function () {
  'use strict'; 

  //Poll the show download page for changes every ten seconds. 
  if ($('#display_download_link').length > 0){
    if($('#download_link').length === 0) {
      setInterval(addDownloadLink, 3000); 
    }  
  }


  function addDownloadLink() {
    var comp_id = $("#data").attr('data-comp-id')
    $.getScript('/compilations/' + comp_id + '/ping.js?comp_id=' + comp_id); 
  }
});