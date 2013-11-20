class User < ActiveRecord::Base
  # Connects this user object to Sufia behaviors. 
  include Sufia::User
  # Connects this user object to Hydra behaviors. 
  include Hydra::User
  # Connects this user object to Blacklights Bookmarks. 
  include Blacklight::User

  after_create :link_to_drs
  before_destroy :remove_drs_object

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  # attr_accessible :title, :body

  attr_accessible :password, :password_confirmation, :remember_me

  ROLES = %w[admin employee] 

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

  def admin?
    return self.role.eql?('admin')
  end

  private
    def link_to_drs
      Sufia.queue.push(EmployeeCreateJob.new(self.nuid))
    end

    def remove_drs_object
      if Employee.exists_by_nuid?(self.nuid)
        object = Employee.find_by_nuid(self.nuid)
        object.destroy
      end
    end
end
