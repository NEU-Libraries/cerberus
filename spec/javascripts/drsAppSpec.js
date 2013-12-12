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
    it('should listen for the use to click on the a link or button element and toggle the target containers class based on that', function(){
      expect($('button[data-target="drs-items-grid"]')).toHaveClass('active');
      $('button[data-target="drs-items-list"]').trigger('click');
      expect($('button[data-target="drs-items-list"]')).toHaveClass('active');
      expect($('#drsDummyItems')).toHaveClass('drs-items-list');
      expect($('#drsDummyItems')).not.toHaveClass('drs-items-grid');



      $('button[data-target="drs-items-grid"]').trigger('click');
      expect($('button[data-target="drs-items-grid"]')).toHaveClass('active');
      expect($('#drsDummyItems')).toHaveClass('drs-items-grid');
      expect($('#drsDummyItems')).not.toHaveClass('drs-items-list');

    });
  });
  


});
  