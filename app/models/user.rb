class User < ActiveRecord::Base
  # Connects this user object to Sufia behaviors.
  include Sufia::User
  # Connects this user object to Hydra behaviors.
  include Hydra::User
  # Connects this user object to Blacklights Bookmarks.
  include Blacklight::User

  before_destroy :remove_drs_object

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :omniauthable, :omniauth_providers => [:shibboleth]
  # attr_accessible :title, :body

  attr_accessible :password, :password_confirmation, :remember_me, :nuid, :full_name, :view_pref

  ROLES = %w[admin employee]

  def groups
    return self.group_list ? self.group_list.split(";") : []
  end

  def self.find_for_shib(auth, signed_in_resource=nil)
    user = User.where(:email => auth.info.email).first

    unless user
      user = User.create(email:auth.info.email, password:Devise.friendly_token[0,20], full_name:auth.info.name, nuid:auth.info.nuid)
      if(auth.info.employee == "staff")
        EmployeeCreateJob.new(auth.info.nuid, auth.info.name)
      end
    end

    return user
  end

  # Method added by Blacklight; Blacklight uses #to_s on your
  # user class to get a user-displayable login/identifier for
  # the account.
  def to_s
    self.email
  end

  def name
    self.full_name
  end

  # Currently using group_list attribute as though it will someday contain the grouper information
  # pulled in from Shibboleth

  def admin?
    return self.role.eql?('admin')
  end

  def user_key
    self.nuid
  end

  def self.find_by_user_key(key)
    self.send("find_by_nuid".to_sym, key)
  end

  private

    def remove_drs_object
      if !self.nuid.nil?
        if Employee.exists_by_nuid?(self.nuid)
          object = Employee.find_by_nuid(self.nuid)
          object.destroy
        end
      end
    end
end
