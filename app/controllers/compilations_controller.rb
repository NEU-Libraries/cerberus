class CompilationsController < ApplicationController 

  before_filter :authenticate_user! 

  def index 
    @compilations = Compilation.users_compilations(current_user) 
  end

  def new 
    @compilation = Compilation.new
  end

  def create
    @compilation = Compilation.new(pid: mint_unique_pid)
    @compilation.attributes = params[:compilation]

    # Set the depositor and give him edit access on the object 
    @compilation.depositor = current_user.nuid 

    if @compilation.save!
      flash[:notice] = "Collection created successfully"  
      redirect_to @compilation 
    else 
      flash.now.error = "Collection was not saved successfully" 
    end   
  end

  def edit
    load_instance 
  end

  def update
    load_instance
  end 

  def show
    load_instance

    if current_user.nuid != @compilation.depositor 
      render_403 
    end
  end

  def destroy 

  end

  private

  def load_instance
    @compilation = Compilation.find(params[:id]) 
  end

  def mint_unique_pid 
    Sufia::Noid.namespaceize(Sufia::IdService.mint)
  end
end