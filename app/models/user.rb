class User < ActiveRecord::Base
# Connects this user object to Sufia behaviors. 
 include Sufia::User
# Connects this user object to Hydra behaviors. 
 include Hydra::User
# Connects this user object to Blacklights Bookmarks. 
 include Blacklight::User
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
end
