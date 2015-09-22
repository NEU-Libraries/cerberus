require 'spec_helper'

describe ShoppingCartsController do
  let(:user) { FactoryGirl.create(:user) }
  let(:file) { FactoryGirl.create(:image_master_file) }
  let(:pdf)  { FactoryGirl.create(:pdf_file) }

  describe "GET #show" do
    before { sign_in user }

    it "loads all objects associated with the current shopping cart" do
      # explicitly save both items and their core records
      # to be sure that they have been solrized
      file.save!
      file.core_record.save!
      pdf.save!
      pdf.core_record.save!

      session[:ids] = [file.pid, pdf.pid]

      get :show

      assigns(:items).length.should == 2
      assigns(:item_core_records).length.should == 2

      cores = assigns(:item_core_records)

      # Ensure that both arrays have been sorted correctly,
      # Pairing each item with its core record by index position
      assigns(:items).each_with_index do |item, i|
        item_parent_id = item["is_part_of_ssim"].first.split("/").last
        item_parent_id == cores.fetch(i)["id"]
      end

      expect(response).to render_template('shopping_carts/show')
    end

    it "handles the empty case" do
      session[:ids] = []
      get :show

      assigns(:items).should == []
      expect(response).to render_template('shopping_carts/show')
    end

    it "handles the case where an item has been tombstoned" do
      root = Collection.create(title: "Root")
      cf = CoreFile.create(title: "Core File One", parent: root, depositor: "nobody@nobody.com")
      cf.save!
      file.core_record = cf
      file.save!

      session[:ids] = [file.pid, pdf.pid]
      cf.tombstone
      cf.save!

      get :show
      assigns(:items).length.should == 1
      expect(response).to render_template('shopping_carts/show')
    end

    it "handles the case where an item has been deleted" do
      session[:ids] = [file.pid, pdf.pid]
      file.delete
      get :show
      assigns(:items).length.should == 1
      expect(response).to render_template('shopping_carts/show')
    end
  end

  describe "PUT #update" do
    before { sign_in user}

    it "allows users to add items they have read permissions for" do
      xhr :put, :update, { add: file.pid }

      session[:ids].should == [file.pid]
      expect(response).to render_template('update')
    end

    it "allows users to remove items from their shopping cart" do
      session[:ids] = [file.pid]
      xhr :put, :update, { delete: file.pid }

      session[:ids].should be_empty
      expect(response).to render_template('update')
    end

    it "fails gracefully when trying to remove from an empty cart" do
      xhr :put, :update, { delete: file.pid }

      session[:ids].should be_empty
      expect(response).to render_template('update')
    end

    it "403s when an user attempts to add an item they don't have permissions for" do
      file.mass_permissions = "private"
      file.save!

      xhr :put, :update, { add: file.pid }

      session[:ids].should be_empty
      response.status.should == 403
    end
  end

  describe "DELETE #destroy" do
    before { sign_in user}
    before { session[:ids] = [file.pid, pdf.pid] }

    it "removes all file pids and redirects to the show page" do
      delete :destroy

      session[:ids].should be_empty
      expect(response).to redirect_to(shopping_cart_path)
    end
  end

  after(:all) do
    ActiveFedora::Base.destroy_all
  end
end
