'use strict';


var drsApp = {
 
    init: function( settings ) {
        drsApp.config = {
            $drsBootstrapSelect: $( "select.bs-select" ),
            $addToSetLink: $('#addToSet'),
            breadCrumbMenuContent: $('#addToSetLinks').html(),
        };
 
        // allow overriding the default config
        $.extend( drsApp.config, settings );
 
        drsApp.setup();
    },
 
    setup: function() {
        drsApp.config.$drsBootstrapSelect.selectpicker();
        drsApp.breadCrumbMenu();
    },
    /**
     * Provides the breadcrumb popover menu for adding collections or new items to the application.
     */
    breadCrumbMenu: function(){
        drsApp.config.$addToSetLink.popover({
            html: true,
            content: drsApp.config.breadCrumbMenuContent,
        }).on('shown', function(event){
          $(this).parent('li').addClass('active');
        }).on('hide', function(event){
          $(this).parent('li').removeClass('active');
        });
    },
    compilationsModal: function(e){
      if( $('#compilationsModal').length > 0){
        var t = $('#compilationsModal');
        t.find('.modal-header').html( e.find('.modal-header').html() );
        t.find('.modal-body').html( e.find('.modal-body').html() );
        console.log($('#new_compilation'));
        $('#new_compilation').bind("ajax:success", function(evt, data, status, xhr){
          console.log($(this), "Ajax Success");
          $(this).parent('#compilationsModal').modal('hide');
        });

      }
      else{
        $('body').append(e.modal({
          replace: true,
        }));
      }
    }
 
};
 
$( document ).ready( drsApp.init({
    // Config can go here eg: $drsBootstrapSelect: $('select.bs-select'),
}) );


