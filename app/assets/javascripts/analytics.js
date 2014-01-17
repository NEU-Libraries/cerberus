/* global jQuery: false */
/* jshint strict: true */
/* global _gaq: false */


'use strict';

(function ($) {
  $( window ).ready(function() {
    

    /**
     * Handles the an jQuery event object.
     * @param  {object}   jQuery Event Object
     * @return {string}   The status of the push.
     */
    var sendEvent = function( event ){
      var data = event.data  || {};
      var eventArray = ['_trackEvent']; //['_trackEvent', 'category', 'action', 'opt_label', opt_value, opt_noninteraction
      
      eventArray.push( data.category || 'default event category');
      eventArray.push( data.action || 'default event action' );
      eventArray.push( data.label || 'default event label' );
      eventArray.push( data.value || 1 );
      eventArray.push( data.nonInteractive || false);
      
      return _gaq.push(eventArray);

    };

    /**
     * Extends the simple send event function to get the pid of the item
     */
    var sendDownloadEvent = function ( event ){
       event.data.label = $(this).closest('.drs-item').data('drsitem');
       sendEvent( event );
    };
    /**
     * Send links ending with the PID to Google Analytics for reporting.
     * 
     */
      $('a[href*="/downloads/"]').on( 'click', {
          category: 'Download',
          action: 'Content Download',
          value: 1,
          nonInteractive: true
      }, sendDownloadEvent );

    
    /**
     * sendPageView for full items
     * @param  {object} element DOM Target to look for 
     * @return {boolean}        Sent i
     */
    var sendPageView = function ( element ){
      var $e = $(element),
      itemPid = '';

      console.log($e);
      if($e.length > 0 ){
        itemPid = $e.data('drsitem');
        console.log(itemPid);
        var status = _gaq.push(['_trackEvent','View', 'Full Item View', itemPid, 1]);
        return status;
      }
      else{
        return false;
      }
    };

    console.log( sendPageView($('.drs-item-full')) );
       
      
      
    

  });
})(jQuery);