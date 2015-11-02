class User < ActiveRecord::Base
  # Connects this user object to Hydra behaviors.
  include Hydra::User
  # Connects this user object to Blacklights Bookmarks.
  include Blacklight::User
  include Mailboxer::Models::Messageable

  before_destroy :remove_drs_object

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :trackable, :validatable, :omniauthable, :omniauth_providers => [:shibboleth]
  # attr_accessible :title, :body

  attr_accessible :password, :email, :password_confirmation, :remember_me, :nuid, :full_name, :view_pref, :employee_id
  delegate :can?, :cannot?, :to => :ability
  serialize(:group_list, Array)

  acts_as_messageable

  ROLES = %w[admin employee]

  def groups
    return !self.group_list.blank? ? self.group_list : []
  end

  def pretty_groups
    if !self.group_list.blank?
      pretty_groups = {}
      self.group_list.each do |group|
        pretty_groups[I18n.t("groups.#{group}.name", :default => group)] = group
      end
      return pretty_groups
    else
      return {}
    end
  end

  def add_group(group)
    gl = self.group_list.blank? ? [] : self.group_list
    gl << group
    self.group_list = gl
    self.save!
  end

  def delete_group(group)
    if !self.group_list.blank?
      gl = self.group_list
      gl.delete(group)
      self.group_list = gl
      self.save!
    end
  end

  def admin_group?
    return self.groups.include? "northeastern:drs:repository:admin"
  end

  def repo_staff?
    return self.groups.include? "northeastern:drs:repository:staff"
  end

  def proxy_staff?
    return self.groups.include? "northeastern:drs:repository:proxystaff"
  end

  def faculty?
    return self.groups.include? "northeastern:drs:faculty"
  end

  def staff?
    return self.groups.include? "northeastern:drs:staff"
  end

  def beta?
    return self.groups.include? "northeastern:drs:repository:beta_users"
  end

  def self.find_for_shib(auth, signed_in_resource=nil)
    user = User.where(:email => auth.info.email).first

    unless user
      name_array = Namae.parse auth.info.name
      name_obj = name_array[0]
      emp_name = "#{name_obj.family}, #{name_obj.given}"

      user = User.create(password:Devise.friendly_token[0,20], full_name:emp_name, nuid:auth.info.nuid)
      user.email = auth.info.email
      user.save!

      if(auth.info.employee == "faculty")
        Cerberus::Application::Queue.push(EmployeeCreateJob.new(auth.info.nuid, emp_name))
      end
    end

    if !auth.info.grouper.nil?
      user.group_list = (auth.info.grouper).split(";")
      user.group_list = user.group_list.uniq
      user.save!
    end

    if(auth.info.employee == "faculty")
      user.add_group("northeastern:drs:faculty")
    elsif(auth.info.employee == "staff")
      user.add_group("northeastern:drs:staff")
    end

    user.add_group("northeastern:drs:all")

    return user
  end

  def employee_pid

    if !self.employee_id.blank?
      return self.employee_id
    end

    @employee = Employee.find_by_nuid(self.nuid)
    if !@employee.nil?
      return @employee.pid
    end
  end

  def ability
    @ability ||= Ability.new(self)
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

  def pretty_name
    if !self.full_name.blank?
      name_array = Namae.parse self.full_name
      name_obj = name_array[0]
      return "#{name_obj.given} #{name_obj.family}"
    end

    # safety return
    return ""
  end

  def admin?
    return self.role.eql?('admin')
  end

  def loader?
    if self.loaders != []
      return true
    else
      return false
    end
  end

  def marcom_loader?
    return self.groups.include? "northeastern:drs:repository:loaders:marcom"
  end

  def coe_loader?
    return self.groups.include? "northeastern:drs:repository:loaders:coe"
  end

  def cps_loader?
    return self.groups.include? "northeastern:drs:repository:loaders:cps"
  end

  def emsa_loader?
    return self.groups.include? "northeastern:drs:repository:loaders:emsa_emc"
  end

  def multipage_loader?
    return self.groups.include? "northeastern:drs:repository:loaders:multipage"
  end

  def loaders
    loaders = []
    if self.marcom_loader?
      loaders.push(I18n.t("drs.loaders.marcom.long_name"))
    end
    if self.coe_loader?
      loaders.push(I18n.t("drs.loaders.coe.long_name"))
    end
    if self.cps_loader?
      loaders.push(I18n.t("drs.loaders.cps.long_name"))
    end
    if self.emsa_loader?
      loaders.push(I18n.t("drs.loaders.emsa.long_name"))
    end
    if self.multipage_loader?
      loaders.push(I18n.t("drs.loaders.multipage.long_name"))
    end
    return loaders
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
