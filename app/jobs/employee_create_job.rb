class EmployeeCreateJob
  attr_accessor :nuid, :name, :preexisting_smart_collection_titles

  def initialize(nuid, name)
    self.nuid = nuid
    self.name = name
  end

  def queue_name
    :employee_create
  end

  def run
    # Spin up an employee marked as building
    # Make sure the employee doesn't exist before we try that.
    # Would implement some sort of Employee.find_or_create but this is the only place
    # we'd ever use it.
    if Employee.exists_by_nuid?(self.nuid)
      emp = Employee.find_by_nuid(self.nuid)

      users = User.where(:nuid => self.nuid)

      users.each do |u|
        if !u.nil?
          u.employee_id = emp.pid
          u.save!
        end
      end

      return
    else
      emp = Employee.create(nuid: self.nuid, name: self.name, building: true, mass_permissions: 'public')
    end

    titles = emp.smart_collections.map { |x| x.title }
    self.preexisting_smart_collection_titles = titles

    parent = create_personal_collection(self.name, emp)
    create_personal_collection("Research Publications", emp, parent)
    create_personal_collection("Other Publications", emp, parent)
    create_personal_collection("Presentations", emp, parent)
    create_personal_collection("Datasets", emp, parent)
    create_personal_collection("Technical Reports", emp, parent)
    create_personal_collection("Learning Objects", emp, parent)
    create_personal_collection("Monographs", emp, parent)

    # Tag the employee as completed and resave to Fedora.
    emp.employee_is_complete
    emp.save!

    u = User.find_by_nuid(self.nuid)
    if !u.nil?
      u.employee_id = emp.pid
      u.save!
    end

    # As long as emp has been initialized to an Employee object
    # and has been persisted to Fedora we need to send this email
    if (emp.instance_of? Employee) && emp.persisted?
      EmployeeMailer.new_employee_alert(emp).deliver!
    end
  end

  private
    def create_personal_collection(title, employee, parent = nil)
      unless preexisting_smart_collection_titles.include?(title)
        if title == employee.name
          smart_collection_type = "User Root"
          desc = "#{self.name}'s root collection"
        else
          smart_collection_type = "#{title}"
          desc = "#{title} deposited by, or on behalf of, #{employee.pretty_employee_name}"
        end

        attrs = {
                  pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint),
                  title: title,
                  depositor: self.nuid,
                  parent: parent,
                  user_parent: employee,
                  description: desc,
                  smart_collection_type: smart_collection_type,
                  mass_permissions: 'public',
                }

        personal_collection = Collection.new(attrs)

        # Create a handle
        personal_collection.identifier = make_handle("#{Rails.configuration.persistent_collection_path}#{personal_collection.pid}")
        # Add drs staff to permissions for #1063
        personal_collection.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")

        saves = 0

        # Attempt to save the newly created collection
        begin
          return personal_collection if personal_collection.save!
        rescue RSolr::Error::Http => error
          puts "Save failed"
          saves += 1
          logger.warn "EmployeeCreateJob caught RSOLR error on creation of #{nuid}'s #{title} personal_collection: #{error.inspect}"
          raise error if saves >= 3
          sleep 0.01
          retry
        end
      end
    end
end
