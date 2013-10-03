module Drs::Employee::FacultyFolders
  extend ActiveSupport::Concern

  included do 
    after_destroy :purge_personal_graph
  end

  def root_folder 
    return find_by_folder_type('user root')  
  end

  def research_publications 
    return find_by_folder_type('research publications')  
  end

  def other_publications 
    return find_by_folder_type('other publications')
  end

  def data_sets 
    return find_by_folder_type('data sets') 
  end

  def presentations 
    return find_by_folder_type('presentations') 
  end

  def learning_objects
    return find_by_folder_type('learning objects') 
  end

  def sorted_folders 
    return [research_publications, other_publications, data_sets, presentations, learning_objects] 
  end

  def personal_folders 
    return self.folders.select { |f| f.personal_folder_type == 'miscellany' && f.parent.pid == self.root_folder.pid } 
  end

  private

    def find_by_folder_type(string) 
      return self.folders.find{ |f| f.personal_folder_type == string } 
    end

    def purge_personal_graph
      self.root_folder.recursive_delete if !self.folders.empty?
    end
end