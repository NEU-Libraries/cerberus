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
            console.log('ajax successful, but not sure what to do!')
          break;
        }
        
      }).on('ajax:error', function(evt, data, status, xhr){
          var error = $('<div class="alert alert-warning"/>');
          error.append($('<button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>')).append($('<strong>Oh no, something went strong!</strong>')).append(xhr);
          $(this).closest('.modal-body').append(error);
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
          $('#compilationsModal').modal().modal('hide');

          //$(this).closest('#compilationsModal').remove();
        });

      }
      else{
        $('body').append(e.modal({
          replace: true,
        }));
      }
      drsApp.addToComplationLink($('.btn-compilation'));
    },
    
 
};
 
$( document ).ready( drsApp.init({
    // Config can go here eg: $drsBootstrapSelect: $('select.bs-select'),
}) );


