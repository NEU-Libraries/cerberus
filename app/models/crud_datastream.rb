class CrudDatastream < ActiveFedora::OmDatastream
  include OM::XML::Document 

  set_terminology do |t| 
    t.root(path: 'crud', 'xmlns:crud' => 'http://repository.neu.edu/schema/crud', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://repository.neu.edu/schema/crud http://repository.neu.edu/schema/crud/crud.xsd') 
    t.create_space(path: 'create', namespace_prefix: 'crud'){
      t.identity(path: 'identity', namespace_prefix: 'crud'){
        t.identity_type(path: { attribute: 'type' }) 
      }
    }
    t.read_space(path: 'read', namespace_prefix: 'crud'){
      t.identity(path: 'identity', namespace_prefix: 'crud'){
        t.identity_type(path: { attribute: 'type' })
      }
    }
    t.update_space(path: 'update', namespace_prefix: 'crud'){
      t.identity(path: 'identity', namespace_prefix: 'crud'){
        t.identity_type(path: { attribute: 'type' })
      }
    }
    t.delete_space(path: 'delete', namespace_prefix: 'crud'){
      t.identity(path: 'identity', namespace_prefix: 'crud'){
        t.identity_type(path: { attribute: 'type' }) 
      }
    }
  end

  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml| 
      xml.crud('xmlns:crud' => 'http://repository.neu.edu/schema/crud', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 
                    'xsi:schemaLocation' => 'http://repository.neu.edu/schema/crud http://repository.neu.edu/schema/crud/crud.xsd'){
        xml.parent.namespace = xml.parent.namespace_definitions.find{ |ns| ns.prefix=="crud"}
        xml['crud'].create
        xml['crud'].read
        xml['crud'].update
        xml['crud'].delete
      }
    end
    builder.doc 
  end


  # Mass assign perms for user with name 'name' and type of 'type'.
  # Valid options for the array are :create, :read, :update, and :destroy. 
  def mass_add_perm(type, name, array_of_symbols)
    array_of_symbols.each do |sym|
      single_add_perm(type, name, sym)
    end
  end

  #Add a group/individual to the create permission space.
  def add_create_perm(type, name)
    add_perm(type, name, :create_root) 
  end

  #Remove a group/individual from the create permission space.
  def remove_create_perm(type, name) 
    remove_perm(type, name, :create_root)  
  end

  def add_read_perm(type, name)
    add_perm(type, name, :read_root) 
  end

  def remove_read_perm(type, name)
    remove_perm(type, name, :read_root) 
  end

  def add_update_perm(type, name)
    add_perm(type, name, :update_root)
  end

  def remove_update_perm(type, name)
    remove_perm(type, name, :update_root) 
  end

  def add_destroy_perm(type, name)
    add_perm(type, name, :delete_root)
  end

  def remove_destroy_perm(type, name)
    remove_perm(type, name, :delete_root)
  end

  #Gets us to <crud:create> in the XML document 
  def create_root
    create_space 
  end

  def read_root
    read_space 
  end

  def update_root
    update_space 
  end

  def delete_root
    delete_space
  end

    
  private

    def single_add_perm(type, name, symbol)
      if symbol == :create 
        add_perm(type, name, :create_root)
      elsif symbol == :read 
        add_perm(type, name, :read_root) 
      elsif symbol == :update 
        add_perm(type, name, :update_root) 
      elsif symbol == :delete 
        add_perm(type, name, :delete_root) 
      else
        raise "#{symbol} is not a valid permission to pass" 
      end
    end

    def single_remove_perm(type, name, symbol)
      if symbol == :create 
        remove_perm(type, name, :create_root) 
      elsif symbol == :read 
        remove_perm(type, name, :read_root) 
      elsif symbol == :update 
        remove_perm(type, name, :update_root) 
      elsif symbol == :delete 
        remove_perm(type, name, :delete_root)
      else
        raise "#{symbol} is not a valid permission to pass" 
      end
    end
  
    def add_perm(type, name, root_func)
      root_space = self.send(root_func) 
      original_length = root_space.identity.length

      if(not(type =='individual' || type == 'managed group'))
        raise "Identities must be of type 'individual' or type 'managed group'"
      end

      if(perm_exists?(type, name, root_func))
        raise "Node for #{type} '#{name}' already exists in #{root_func.to_s}"
      end

      if(original_length == 0) 
        root_space.identity = name 
      else
        root_space.identity = root_space.identity.append(name)
      end

      root_space.identity(original_length).identity_type = type
    end

    def remove_perm(type, name, root_func)
      targetted_perm_rs = lookup_perm(type, name, root_func) 

      if targetted_perm_rs.length == 1
        targetted_perm_rs.first.remove
        return true 
      elsif targetted_perm_rs.length == 0 
        return false 
      else
        raise "#{targetted_perm_rs.length} matches detected, indicating data corruption.  Please clean by hand" 
      end
    end

    def find_xpath_node_name_by_function(root_func)
      if root_func == :create_root 
        return 'crud:create' 
      elsif root_func == :read_root 
        return 'crud:read' 
      elsif root_func == :update_root 
        return 'crud:update' 
      elsif root_func == :delete_root 
        return 'crud:delete' 
      else
        raise "#{root_func} does not map to a valid space within the terminology" 
      end
    end  

    def perm_exists?(type, name, root_func)
      lookup_result_count = lookup_perm(type, name, root_func).length 

      if lookup_result_count == 0 
        return false
      else
        return true 
      end 
    end

    def lookup_perm(type, name, root_func)
      xpath_root_element = find_xpath_node_name_by_function(root_func)
      xpath_query = "//" + xpath_root_element + "/crud:identity[@type='#{type}' and text()='#{name}']" 

      xpath_result_set = self.find_by_terms(xpath_query) 

      return xpath_result_set
    end
end