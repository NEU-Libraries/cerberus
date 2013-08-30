require 'spec_helper' 

describe CompilationsController do 
  let(:bill) { FactoryGirl.create(:bill) }
  let(:bo) { FactoryGirl.create(:bo) }  

  describe "GET #new" do

    before :each do 
      sign_in bill 
    end

    it "instantiates a blank compilation" do
      get :new 

      assigns(:compilation).should be_instance_of(Compilation)
    end 

    it "renders the new compilation template for authenticated users" do
      get :new 

      expect(response).to render_template('compilations/new') 
    end

    it "boots out users who aren't signed in" do 
      sign_out bill 

      get :new 

      expect(response).to redirect_to(new_user_session_path)  
    end
  end

  describe "POST #create" do 
    before :each do 
      sign_in bill 
    end

    it "boots out users who aren't signed in" do 
      sign_out bill 

      post :create

      expect(response).to redirect_to(new_user_session_path) 
    end

    it "creates a new compilation on successful post" do
      attrs = { 'title' => 'My collection', 'description' => 'A collection' } 

      post :create, :compilation => attrs

      assigns(:compilation).title.should == "My collection" 
      expect(response).to redirect_to(compilation_path(id: assigns(:compilation).pid)) 
    end
  end

  describe "GET #show" do 
    let(:compilation) { FactoryGirl.create(:bills_compilation) } 

    it "boots out users who aren't signed in" do 
      sign_out bill 

      get :show, :id => compilation.pid 

      expect(response).to redirect_to(new_user_session_path) 
    end

    it "renders the template for the depositing owner" do
      sign_in bill

      get :show, id: compilation.pid

      expect(response).to render_template('compilations/show') 
    end

    it "renders an error page for users besides the depositor who attempt access" do
      sign_in bo 

      get :show, id: compilation.pid 

      response.status.should == 403
    end 
  end
end