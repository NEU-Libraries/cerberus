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
    breadCrumbMenu: function(){
        drsApp.config.$addToSetLink.popover({
            html: true,
            content: drsApp.config.breadCrumbMenuContent,
        });
    }
   
 
};
 
$( document ).ready( drsApp.init({
    // Config can go here eg: $drsBootstrapSelect: $('select.bs-select'),
}) );
