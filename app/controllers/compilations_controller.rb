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

    save_or_bust @compilation
  end

  def edit
    load_instance 
  end

  def update
    load_instance
    if @compilation.update_attributes(params[:compilation])
      flash[:notice] = "Compilation successfully updated" 
      redirect_to @compilation 
    else
      flash.now.error = "Compilation failed to update" 
    end 
  end 

  def show
    load_instance

    if current_user.nuid != @compilation.depositor 
      render_403 
    end
  end

  def destroy 
    load_instance 
    if @compilation.destroy
      flash[:notice] = "Compilation was successfully destroyed" 
      redirect_to compilations_path 
    else
      flash.now.error = "Compilation #{@compilation.title} was not successfully destroyed" 
    end 
  end

  def add_file
    load_instance 
    @compilation.add_entry(params[:entry_id]) 
    save_or_bust @compilation 
  end

  def delete_file
    load_instance
    @compilation.remove_entry(params[:entry_id])  
    save_or_bust @compilation 
  end

  def download 
    load_instance
    Sufia.queue.push(ZipCompilationJob.new(@compilation)) 
  end

  private

  def save_or_bust(compilation) 
    if compilation.save! 
      flash[:notice] = "Compilation successfully updated" 
      redirect_to compilation 
    else
      flash.now.error = "Compilation was not successfully updated" 
    end
  end

  def load_instance
    @compilation = Compilation.find(params[:id]) 
  end

  def mint_unique_pid 
    Sufia::Noid.namespaceize(Sufia::IdService.mint)
  end
end