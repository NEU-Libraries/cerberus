require 'spec_helper'

describe GroupPermissionsSetter do
  let(:compilation) { Compilation.new }
  let(:depositor)   { FactoryGirl.create(:bill) }

  it "cannot be used to add the 'public' group" do
    group_hsh = { access: ["edit"], name: ["public"] }
    g = GroupPermissionsSetter.new(compilation, group_hsh)
    obj = g.set_permissions
    expect(obj.read_groups).not_to include "public"
  end

  it "cannot be used to remove the 'public' group" do
    group_hsh = { permissionless_groups: "public" }
    g = GroupPermissionsSetter.new(compilation, group_hsh)
    g.object.mass_permissions = 'public'
    obj = g.set_permissions
    expect(obj.mass_permissions).to eq "public"
  end

  it "will always apply an addition after a removal" do
    group_hsh = { permissionless_groups: "neu:test",
                  access: ["edit"],
                  name:   ["neu:test"]}
    g = GroupPermissionsSetter.new(compilation, group_hsh)
    obj = g.set_permissions
    expect(obj.edit_groups).to include "neu:test"
  end

  it "raise an exception on unequal length name/access arrays" do
    group_hsh = { access: ["read", "read"], name: ["neu:test"] }
    g   = GroupPermissionsSetter.new(compilation, group_hsh)
    e   = Exceptions::AccessNameMismatchError
    expect{g.set_permissions}.to raise_error e
  end

  it "removes groups specified in the permissionless_groups array" do
    compilation.read_groups = ["g1", "g2"]
    compilation.edit_groups = ["g3"]

    group_hsh = { permissionless_groups: "g1 ; g2 ; g3" }

    g   = GroupPermissionsSetter.new(compilation, group_hsh)
    obj = g.set_permissions
    expect(obj.permissions).to eq []
  end
end
