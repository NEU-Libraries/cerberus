class SignificantContentController < ApplicationController 

  def research 
    @content = fetch_all(:research_publications)
  end

  def presentations 
    @content = fetch_all(:presentations) 
  end

  def learning_objects 
    @content = fetch_all(:learning_objects)
  end

  def datasets 
    @content = fetch_all(:data_sets) 
  end

  def other 
    @content = fetch_all(:other_publications)
  end

  private 

    def fetch_all(content_type) 
      Department.all.inject([]) { |acc, dept| acc + dept.send(content_type) }
    end
end