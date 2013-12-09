'use strict';
/* jshint undef: true, unused: true */
/*global $:false */
/*global Modernizr */


$( document ).ready(function() {
  var drsApp = (function() {
   
      var init = function( settings ) {
          drsApp.config = {
              $drsBootstrapSelect: $( 'select.bs-select' ),
              $addToSetLink: $('#addToSet'),
              breadCrumbMenuContent: $('#addToSetLinks').html(),
              fitTextTarget: $('.fit-text')
          };
   
          // allow overriding the default config
          $.extend( drsApp.config, settings );
   
          setup();
      },
   
      setup = function() {
          drsApp.config.$drsBootstrapSelect.selectpicker();
          breadCrumbMenu();
          handleFitText();
          tooltipSetup();
          handleRequiredInputs();
          ellipsisExpand();
          drsToggleView();
      },
      /**
       * Provides the breadcrumb popover menu for adding collections or new items to the application.
       */
      breadCrumbMenu = function(){
          drsApp.config.$addToSetLink.popover({
              html: true,
              content: drsApp.config.breadCrumbMenuContent,
          }).on('shown', function(){
            $(this).parent('li').addClass('active');
          }).on('hide', function(){
            $(this).parent('li').removeClass('active');
          });
      },

      addToComplationLink =  function(e){
        e.on('ajax:success', function( ){
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
            default:
              console.log('ajax successful, but not sure what to do!');
            break;
          }
          
        }).on('ajax:error', function(){
          $(this).closest('.modal').modal('hide');
           $('.breadcrumb').addBsAlert({
            classes: 'alert alert-danger',
            strong: 'Error,',
            text: 'Something went wrong, please reload the page and try again.',
           });

        });
      },
      newCompilationForm =  function(){
        $('#new_compilation').on('ajax:success', function(){
          $(this).closest('.modal').modal('hide');
           $('.breadcrumb').addBsAlert({
            classes: 'alert alert-success',
            strong: 'Success!',
            text: 'You created a new compilation!',
           });
        }).on('ajax:error', function(){
          $(this).closest('.modal').modal('hide');
           $('.breadcrumb').addBsAlert({
            classes: 'alert alert-danger',
            strong: 'Error,',
            text: 'Something went wrong, please reload the page and try again.',
           });

        });
      },
      compilationsModal =  function(e){
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
      handleFitText = function(){
        if (drsApp.config.fitTextTarget.length > 0 && window.Modernizr){
          Modernizr.load({
            load: '//cdnjs.cloudflare.com/ajax/libs/FitText.js/1.1/jquery.fittext.min.js',
             complete: function () {
                if ( !$.fitText ) {
                    Modernizr.load('/assets/polyfills/FitText-js/jquery.fittext.js');
                }
                drsApp.config.fitTextTarget.fitText();
              }
          });
        }


      },
      /**
       * Tooltip Setup
       */
      tooltipSetup =  function(){
        $('body').tooltip({
            selector: 'a[data-toggle=tooltip]'
          });
      },

      /**
       * Builds interaction to inputs with [required="required"] to make sure that the user fills it out.
       */
      handleRequiredInputs = function(){
        //Query for inputs textareas and selects with require
        var targets = $('input, textarea, select').filter('[required="required"]');
        //Construct the tooltips for inputs that need to be filled still.
        var addTooltip = function(e){
          return $(e).tooltip({
            title: 'Required'
          });
        };
        //cycle through each function.
        targets.each(function(index, el) {
          
          var id = $(el).attr('id');
          //add the required class.
          $('label[for="' + id +'"]').addClass('required-label');
          
          // Check the element to figure out if we still need the tooltip or not.
          
          $(el).on('focus hover click change keypress', function(){
            if($(this).val().length > 0 ){
              $(this).tooltip('destroy');
            }else{
              addTooltip(this);
            }
          });
        });
      },
      
      ellipsisExpand = function(){
        var $toggleLink = $('*[data-toggle="ellipsis"]');

        //look for the target and toggle classes on that element.
        var toggleState = function(event){
          //stop the event from triggering other reations
          event.preventDefault();
          event.stopPropagation();
          var $target = $(this).attr('href').length > 0 ? $($(this).attr('href')) : $($(this).data('target'));
          if ($target.length > 0 ){
            if ( ! $target.hasClass('ellipsis') ){
              $target = $target.find('.ellipsis');
            }
            $target.toggleClass('in');
            $(this).children('i').toggleClass('icon-expand-alt').toggleClass('icon-collapse-alt');
          }else{
            console.log('Invalid target specified for drsApp.ellipsisExpand' , $target);
          }
        };
      $toggleLink.on('click', toggleState );
        
      };

      var drsToggleView = function(){
       var handleClick = function(event){
        event.stopPropagation();
        var toggleContainer = $(this).closest('*[data-container]');
        var container = $( toggleContainer.data('container') );
        var desiredClass = $(this).data('target');
        if (container.hasClass(desiredClass)){
          event.preventDefault();
        }else{
          toggleContainer.find('a, button').removeClass('active');
          $(this).addClass('active');
          console.log(desiredClass);
          if (desiredClass === 'drs-items-grid' ){
            container.removeClass('drs-items-list').addClass('drs-items-grid');
            
          }else{
            container.removeClass('drs-items-grid').addClass('drs-items-list');

          }
        }
        
        
       } 
       $('[data-toggle="drs-item-views-radio"]').on('click', 'a , button', handleClick);

      } 

      // these are the public API
      return{
        init: init,
        addToComplationLink: addToComplationLink,
        newCompilationForm: newCompilationForm,
        compilationsModal: compilationsModal

      }

   
  })();
  //end drsApp module;
  
  window.drsApp = drsApp;
  drsApp.init();
});
 



