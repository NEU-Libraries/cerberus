describe('The drsApp should provide global app functions', function() {
  
  it('it should attach a click listener to a[data-toggle] with an [href] target to toggle the ellipsis style by adding the `in` event class, it should toggle the icon-font class from expand to collapse'  , function() {
    
    
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
  