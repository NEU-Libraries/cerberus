describe('The drsApp object', function() {
  describe('create a show and hide link for longer page excerpts',function(){
    
    it('should attach a click listener to a[data-toggle] with an [href] target to toggle the ellipsis style by adding the `in` event class, it should toggle the icon-font class from expand to collapse'  , function() {
      var fixtures = loadFixtures('drsApp-ellipsis.html');
      
        drsApp.init();
        
          var icon = $('i');
          var link = $('#abstract5Toggle');
          
          expect(icon).toHaveClass('icon-expand-alt');
          expect(icon).not.toHaveClass('icon-collapse-alt');
          
          expect($('#abstract5').find('.ellipsis')).not.toHaveClass('in'); 
          
          $(link).trigger('click');
        
          expect(icon).toHaveClass('icon-collapse-alt');
          expect(icon).not.toHaveClass('icon-expand-alt');
          expect($('#abstract5').find('.ellipsis')).toHaveClass('in'); 
      
      
      
    });
  
  });
  
  describe('creates a breadcrumb menu from the click actions', function(){
    var link, addToSetLinks;
    beforeEach(function(){
      loadFixtures('breadcrumb-menu.html');
      drsApp.init();
      link = $('#addToSet');
      addToSetLinks = $('#addToSetLinks');
      return link, addToSetLinks;
    });

    it('should show the popover menu when the link is clicked', function(){      

      expect(addToSetLinks).not.toBeVisible();
      expect($('.popover')).not.toExist();

      link.trigger('click');

      expect(link.closest('li')).toHaveClass('active');
      expect($('.popover')).toExist();
      expect($('.popover')).toBeVisible();
      expect($('.popover')).toContainHtml(addToSetLinks.html());
    });
    it('should hide the menu when the link is clicked again', function(){
      link.trigger('click');

      link.on('hide', function(){
        expect(link.closest('li')).not.toHaveClass('active');
        expect($('.popover')).not.toBeVisible();
        expect($('.popover')).toContainHtml(addToSetLinks.html());
      });
      
    });
  });
  
  describe('toggles the view class for drs-items',function(){
    beforeEach(function(){
      loadFixtures('drsAppToogleView.html');
      drsApp.init();
    });
    it('should listen for the use to click on the a link or button element and toggle the target containers class based on that and make sure that all items are not active', function(){
      expect($('button[data-target="drs-items-grid"]')).toHaveClass('active');
      $('button[data-target="drs-items-list"]').trigger('click');
      expect($('button[data-target="drs-items-list"]')).toHaveClass('active');
      expect($('#drsDummyItems')).toHaveClass('drs-items-list');
      expect($('#drsDummyItems')).not.toHaveClass('drs-items-grid');


      var item =  $('.drs-item').first();
      item.addClass('active');
      $('button[data-target="drs-items-grid"]').trigger('click');
      expect($('button[data-target="drs-items-grid"]')).toHaveClass('active');
      expect(item).not.toHaveClass('active');
      expect($('#drsDummyItems')).toHaveClass('drs-items-grid');
      expect($('#drsDummyItems')).not.toHaveClass('drs-items-list');

    });
  });
  describe( 'should listen for the user to click an item and show the user a bigger reveal' , function() { 
    beforeEach(function(){
      loadFixtures('drsAppToogleView.html');
      drsApp.init();
    });
    it('should listen for a click to happen on the item and simply toggle the active class on it or any other items in the container.', function(){

      expect($('#drsItem1')).not.toHaveClass('active');
      expect($('.drs-item')).not.toHaveClass('active');
      
      $('#drsItem1').trigger('click');
      
      expect($('#drsItem1')).toHaveClass('active');


      $('#drsItem1').trigger('click');
      
      expect($('#drsItem1')).not.toHaveClass('active');
      var anotherItem = $('#drsItem1').next('.drs-item');
      
      anotherItem.trigger('click');

      expect( $('#drsItem1') ).not.toHaveClass('active'); 
      expect( anotherItem ).toHaveClass('active');

    });


  });

  describe( 'Should listen for elements with aria-role="checkbox" ' , function(){
    beforeEach(function(){
      loadFixtures('aria-checkbox-fixture.html');
      drsApp.init();
    });

    it( 'should toggle their aria-checked state elements without ajax on' , function(){
      var $checkbox = $( '#notRemoteCheckbox' );
      var role, checked;
      function checkState(){
        role = $checkbox.attr('aria-role');
        checked = $checkbox.attr('aria-checked');
      }
      checkState();
      
      expect( role ).toBe( 'checkbox' );
      expect( checked ).toBe( 'true' );
      
      $checkbox.trigger('click');
      
      checkState();
      console.log(checked); 
      expect( $checkbox.attr('aria-checked') ).toBe( 'false' );

    });
    
    it( 'listends for ajax:success if  there is a data-remote then toggle the state' , function(){
      var $checkbox = $( '#remoteCheckbox' );
      var role, checked;
      function checkState(){
        role = $checkbox.attr('aria-role');
        checked = $checkbox.attr('aria-checked');
      }
      checkState();
      
      expect( role ).toBe( 'checkbox' );
      expect( checked ).toBe( 'true' );
      
      $checkbox.trigger('click');
      expect( checked ).toBe( 'true' );
      $checkbox.trigger('ajax:success');

      
      checkState();
      expect( checked ).toBe( 'false' );
            
    });

  });
  


});
  