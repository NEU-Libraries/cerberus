require 'spec_helper' 

feature "Uploading a single file" do 
  let(:user) { FactoryGirl.create(:user) }

  before { sign_in user }
end 