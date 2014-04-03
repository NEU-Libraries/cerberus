class EmployeeCreateJob
  attr_accessor :nuid, :name

  def initialize(nuid, name)
    self.nuid = nuid
    self.name = name
  end

  def queue_name
    :employee_create_job
  end

  def run

    # Spin up an employee marked as building
    # Make sure the employee doesn't exist before we try that.
    # Would implement some sort of Employee.find_or_create but this is the only place
    # we'd ever use it.
    if Employee.exists_by_nuid?(self.nuid)
      emp = Employee.find_by_nuid(self.nuid)
    else
      emp = Employee.create(nuid: self.nuid, name: self.name, building: true, mass_permissions: 'public')
    end

    # Generate employee's personal graph
    parent = create_folder(self.name, emp)
    create_folder("Research Publications", emp, parent)
    create_folder("Other Publications", emp, parent)
    create_folder("Presentations", emp, parent)
    create_folder("Data Sets", emp, parent)
    create_folder("Learning Objects", emp, parent)

    # Tag the employee as completed and resave to Fedora.
    emp.employee_is_complete
    emp.save!
  end

  private

    def create_folder(title, employee, parent = nil)

      if title == employee.name
        smart_collection_type = "user root"
        desc = "#{self.name}'s root folder"
      else
        smart_collection_type = "#{title}"
        desc = "#{title} for #{employee.name}"
      end

      attrs = {
                title: title,
                depositor: self.nuid,
                parent: parent,
                user_parent: employee,
                description: desc,
                smart_collection_type: smart_collection_type,
                mass_permissions: 'public',
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
        logger.warn "GenerateUsersmart_collectionsJob caught RSOLR error on creation of #{nuid}'s #{title} folder: #{error.inspect}"
        raise error if saves >= 3
        sleep 0.01
        retry
      end
    end
end
