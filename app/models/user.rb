class User < ActiveRecord::Base
  # Connects this user object to Sufia behaviors. 
  include Sufia::User
  # Connects this user object to Hydra behaviors. 
  include Hydra::User
  # Connects this user object to Blacklights Bookmarks. 
  include Blacklight::User

  after_create :link_to_drs
  after_destroy :remove_drs_object

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  # attr_accessible :title, :body

  attr_accessible :password, :password_confirmation, :remember_me 

  # Method added by Blacklight; Blacklight uses #to_s on your
  # user class to get a user-displayable login/identifier for
  # the account. 
  def to_s
    email
  end

  # When we get that Shibboleth stuff sorted we can figure out how to get
  # this to actually be a user's nuid.  For now it's just their email address 
  def nuid 
    email 
  end

  # Currently using group_list attribute as though it will someday contain the grouper information
  # pulled in from Shibboleth

  private
    def link_to_drs
      #We'll be getting these details from shib hopefully. Placeholders there for now.
      new_employee = Employee.new({ nuid: self.nuid, name: "Jane Doe" })
      new_employee.save!
    end

    def remove_drs_object
      queryResult = ActiveFedora::SolrService.query("active_fedora_model_ssi:Employee AND nuid_tesim:'#{self.nuid}', :rows=>999)

      if queryResult.count > 1
        #This shouldn't happen, there should be a one to one relationship
        logger.warn "Multiple Employee objects for #{self.nuid}: #{error.inspect}"
      else
        doc = SolrDocument.new(queryResult.first)
        neuid = doc.id
        employeeRecord = Employee.find(doc.id)
        employeeRecord.destroy
      end
    end
end
