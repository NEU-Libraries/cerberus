'use strict';


var drsApp = {
 
    init: function( settings ) {
        drsApp.config = {
            $drsBootstrapSelect: $( "select.bs-select" ),
            $addToSetLink: $('#addToSet'),
            breadCrumbMenuContent: $('#addToSetLinks').html(),
            fitTextTarget: $('.fit-text')
        };
 
        // allow overriding the default config
        $.extend( drsApp.config, settings );
 
        drsApp.setup();
    },
 
    setup: function() {
        drsApp.config.$drsBootstrapSelect.selectpicker();
        drsApp.breadCrumbMenu();
        drsApp.handleFitText();
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

    addToComplationLink: function(e){
      e.on('ajax:success', function(evt, data, status, xhr){
        var delta = $(this).data('method');
        switch(delta){
          case'post':
            $(this)
              .text($(this).text().replace('Add to', 'Remove from'))
              .data('method', 'delete')
              .removeClass('btn-success add-to-compilation')
              .addClass('btn-danger remove-from-compilation');
          break;
          case 'delete':
              $(this)
              .data('method', 'post')
              .text($(this).text().replace('Remove from', 'Add to' ))
              .addClass('btn-success add-to-compilation')
              .removeClass('btn-danger remove-from-compilation');
          break;
          defualt:
            console.log('ajax successful, but not sure what to do!');
          break;
        }
        
      }).on('ajax:error', function(evt, data, status, xhr){
        $(this).closest('.modal').modal('hide');
         $('.breadcrumb').addBsAlert({
          classes: 'alert alert-danger',
          strong: 'Error,',
          text: 'Something went wrong, please reload the page and try again.',
         });

      });
    },
    newCompilationForm: function(){
      $('#new_compilation').on('ajax:success', function(){
        $(this).closest('.modal').modal('hide');
         $('.breadcrumb').addBsAlert({
          classes: 'alert alert-success',
          strong: 'Success!',
          text: 'You created a new compilation!',
         });
      }).on('ajax:error', function(evt, data, status, xhr){
        $(this).closest('.modal').modal('hide');
         $('.breadcrumb').addBsAlert({
          classes: 'alert alert-danger',
          strong: 'Error,',
          text: 'Something went wrong, please reload the page and try again.',
         });

      });
    },
    compilationsModal: function(e){
      var $modal = $('#ajax-modal');
        
      $modal.empty().append(e).modal('show');
      
      $modal.on('hidden', function(){
        $(this).empty();
      });
      
      drsApp.addToComplationLink($('.btn-compilation'));
      drsApp.newCompilationForm();
    },
    /**
     * Checks the dom to see if the plugin target is there and then loads it with Modernizr
     */
    handleFitText: function(){
      if (drsApp.config.fitTextTarget.length > 0 && window.Modernizr){
        Modernizr.load({
          load: "//cdnjs.cloudflare.com/ajax/libs/FitText.js/1.1/jquery.fittext.min.js",
           complete: function () {
              // if ( !$ ) {
              //   Modernizr.load('/assets/polyfills/respond/respond.min.js');
              drsApp.config.fitTextTarget.fitText();
            }
        }); 
      }



    }
    
 
};



 
$( document ).ready( drsApp.init({
    // Config can go here eg: $drsBootstrapSelect: $('select.bs-select'),
}) );


