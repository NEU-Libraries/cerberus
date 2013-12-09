class SignificantContentController < ApplicationController 

  def theses 
    #TODO: Implement
  end

  def research 
    @content = fetch_all(:research_publications)
  end

  def presentations 
    @content = fetch_all(:presentations) 
  end

  private 

    def fetch_all(content_type) 
      Community.all.inject([]) { |acc, dept| acc + dept.send(content_type) }
    end
end