class User < ActiveRecord::Base
  # Connects this user object to Hydra behaviors.
  include Hydra::User
  # Connects this user object to Blacklights Bookmarks.
  include Blacklight::User
  include Mailboxer::Models::Messageable

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :trackable, :validatable, :omniauthable, :omniauth_providers => [:shibboleth]
  # attr_accessible :title, :body

  attr_accessible :password, :email, :password_confirmation, :remember_me, :nuid, :full_name, :view_pref, :employee_id, :account_pref, :multiple_accounts, :per_page_pref
  delegate :can?, :cannot?, :to => :ability
  serialize(:group_list, Array)

  acts_as_messageable

  ROLES = %w[admin employee developer]

  def associated_accounts
    if self.multiple_accounts
      users = User.where(:nuid => self.nuid)
      return users.map do |u| {:email=>u.email, :account_pref=>u.account_pref, :affiliation=>u.affiliation, :name=>u.name} end
    end
  end

  def groups
    return !self.group_list.blank? ? self.group_list : []
  end

  def pretty_groups
    if !self.group_list.blank?
      pretty_groups = {}
      self.group_list.each do |group|
        pretty_groups[I18n.t("groups.#{group}.name", :default => group)] = group
      end
      return pretty_groups.sort
    else
      return {}
    end
  end

  def add_group(group)
    gl = self.group_list.blank? ? [] : self.group_list
    gl << group
    self.group_list = gl.uniq
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
    users = User.where(:nuid => auth.info.nuid)

    if auth.info.nuid.blank?
      raise Exceptions::NoNuidProvided
    end

    if !auth.info.name.blank?
      name_array = Namae.parse auth.info.name
      if name_array.blank?
        name_array = Namae.parse auth.info.name.titleize
      end
      name_obj = name_array[0]
      emp_name = "#{name_obj.family}, #{name_obj.given}"
    end

    if user.blank? && users.blank?

      user = User.create(password:Devise.friendly_token[0,20], full_name:emp_name, nuid:auth.info.nuid)

      if auth.info.email.blank?
        user.email = auth.info.nuid + "@northeastern.edu"
      else
        user.email = auth.info.email
      end

      if !auth.info.employee.blank?
        user.affiliation = auth.info.employee
      end

      user.save!
    else
      # Previously logged in
      user = User.where(:nuid => auth.info.nuid).first

      # Preferred account?
      if !user.account_pref.blank?
        email = user.account_pref
        user = User.where(:email => email).first
      end
    end

    user.reload

    if user.employee_id.blank?
      if(auth.info.employee.include?("faculty") || auth.info.employee.include?("staff"))
        Cerberus::Application::Queue.push(EmployeeCreateJob.new(auth.info.nuid, emp_name))
      end
    end

    if !auth.info.grouper.nil?
      user.group_list = (auth.info.grouper).split(";")
      user.group_list = user.group_list.uniq
      user.save!
    end

    if auth.info.employee.include?("faculty")
      user.add_group("northeastern:drs:faculty")
    end
    if auth.info.employee.include?("staff")
      user.add_group("northeastern:drs:staff")
    end

    user.add_group("northeastern:drs:all")

    users = User.where(:nuid => auth.info.nuid)
    if users.length > 1
      users.map do |u|
        u.multiple_accounts = true
        u.save!
      end
    end

    # If admin user, copy their groups to 000000000 so that they can impersonate
    # and have access to everywhere they should
    if user.admin?
      user.add_group("northeastern:drs:faculty")
      user.add_group("northeastern:drs:staff")
      user.save!

      system_user = User.find_by_nuid("000000000")
      system_user.group_list = user.group_list
      system_user.save!
    end

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
      if name_array.blank?
        name_array = Namae.parse self.full_name.titleize
      end
      name_obj = name_array[0]
      return "#{name_obj.given} #{name_obj.family}"
    end

    # safety return
    return ""
  end

  def admin?
    return self.role.eql?('admin')
  end

  def developer?
    return self.role.eql?('developer')
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

  def bouve_loader?
    return self.groups.include? "northeastern:drs:repository:loaders:bouve_dean"
  end

  def spreadsheet_loader?
    return self.groups.include? "northeastern:drs:repository:loaders:spreadsheet"
  end

  def damore_loader?
    return self.groups.include? "northeastern:drs:repository:loaders:damore_mckim"
  end

  def aaia_loader?
    return self.groups.include? "northeastern:drs:repository:loaders:aai_archives"
  end

  def libcom_loader?
    return self.groups.include? "northeastern:drs:repository:loaders:libcom"
  end

  def xml_loader?
    return self.groups.include? "northeastern:drs:repository:loaders:xml"
  end


  def loaders
    loaders = []
    I18n.t('loaders').each do |key, loader|
      if self.send("#{loader[:short_name]}_loader?")
        loaders.push(loader[:long_name])
      end
    end
    return loaders
  end


  def user_key
    self.nuid
  end

  def self.find_by_user_key(key)
    self.send("find_by_nuid".to_sym, key)
  end

end
