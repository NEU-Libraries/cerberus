class MonographRefactorJob

  def queue_name
    :monograph_refactor
  end

  def run
    # Find all employees that don't have a monograph smart collection
    Employee.find(:all).each do |emp|
      has_monographs = false

      parent = emp.user_root_collection
      sc = emp.smart_collections

      sc.each do |col|
        if col.smart_collection_type == "Monographs"
          has_monographs = true
        end
      end

      if !has_monographs
        create_personal_collection("Monographs", emp, parent)

        # Tag the employee as completed and resave to Fedora.
        emp.employee_is_complete
        emp.save!
      end
    end
  end

  private
    def create_personal_collection(title, employee, parent = nil)
      if title == employee.name
        smart_collection_type = "User Root"
        desc = "#{self.name}'s root collection"
      else
        smart_collection_type = "#{title}"
        desc = "#{title} deposited by, or on behalf of, #{employee.pretty_employee_name}"
      end

      attrs = {
                title: title,
                depositor: employee.nuid,
                parent: parent,
                user_parent: employee,
                description: desc,
                smart_collection_type: smart_collection_type,
                mass_permissions: 'public',
              }

      personal_collection = Collection.new(attrs)

      saves = 0

      # Attempt to save the newly created collection
      begin
        return personal_collection if personal_collection.save!
      rescue RSolr::Error::Http => error
        puts "Save failed"
        saves += 1
        logger.warn "EmployeeCreateJob caught RSOLR error on creation of #{employee.nuid}'s #{title} personal_collection: #{error.inspect}"
        raise error if saves >= 3
        sleep 0.01
        retry
      end
    end
end
