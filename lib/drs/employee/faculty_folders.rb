module Drs::Employee::FacultyFolders
  extend ActiveSupport::Concern

  included do
    after_destroy :purge_personal_graph
  end

  def root_folder
    find_by_folder_type('user root')
  end

  def research_publications
    find_by_folder_type('research publications')
  end

  def all_research_publications
    research_publications.all_descendent_files
  end

  def other_publications
    find_by_folder_type('other publications')
  end

  def all_other_publications
    other_publications.all_descendent_files
  end

  def data_sets
    find_by_folder_type('data sets')
  end

  def all_data_sets
    data_sets.all_descendent_files
  end

  def presentations
    find_by_folder_type('presentations')
  end

  def all_presentations
    presentations.all_descendent_files
  end

  def learning_objects
    find_by_folder_type('learning objects')
  end

  def all_learning_objects
    learning_objects.all_descendent_files
  end

  def sorted_folders
    [research_publications, other_publications, data_sets, presentations, learning_objects]
  end

  def personal_folders
    self.folders.select { |f| f.personal_folder_type == 'miscellany' && f.parent.pid == self.root_folder.pid }
  end

  private

    def find_by_folder_type(string)
      return self.folders.find{ |f| f.personal_folder_type == string && f.parent.pid == self.root_folder.pid }
    end

    def purge_personal_graph
      self.root_folder.recursive_delete if !self.folders.empty?
    end
end
