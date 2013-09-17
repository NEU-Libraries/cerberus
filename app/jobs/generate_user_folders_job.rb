class GenerateUserFoldersJob 
  attr_accessor :nuid, :name, :emp_id

  def initialize(employee_id, nuid, name)
    self.emp_id = employee_id 
    self.nuid = nuid 
    self.name = name 
  end

  def queue_name 
    :generate_user_folders
  end

  def run
    parent = create_folder("User Root") 
    create_folder("Research Publications", parent)
    create_folder("Other Publications", parent) 
    create_folder("Presentations", parent)
    create_folder("Data Sets", parent)
    create_folder("Learning Objects", parent)  
  end

  private

    def create_folder(title, parent = nil)
      attrs = { 
                title: title, 
                depositor: self.nuid, 
                parent: parent,
                user_parent: Employee.find(self.emp_id), 
                description: "#{title} for #{self.name}",
                personal_folder_type: "#{title.downcase}", 
                mass_permissions: 'private',
              }

      folder = NuCollection.new(attrs) 

      saves = 0

      #Attempt to save the newly created folder 
      begin 
        if folder.save!
          return folder
        end 
      rescue RSolr::Error::Http => error
        puts "Save failed" 
        saves += 1 
        logger.warn "GenerateUserFoldersJob caught RSOLR error on creation of #{nuid}'s #{title} folder: #{error.inspect}" 
        raise error if saves >= 3 
        sleep 0.01 
        retry 
      end
    end
end
