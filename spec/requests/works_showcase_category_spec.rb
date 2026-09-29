# frozen_string_literal: true

require 'rails_helper'

# The Showcase category choice on the Work edit form, against the live Atlas test
# backend: real showcases, a real depositor-owned Work, and the real
# AtlasRb::System link calls, so Atlas's own :link_member scoping is exercised.
RSpec.describe 'Works showcase category', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:fixtures)   { '/home/cerberus/web/spec/fixtures/files' }
  let(:community)  { AtlasRb::Community.create(nil, "#{fixtures}/community-mods.xml", nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, "#{fixtures}/collection-mods.xml", nuid: '000000004') }
  let(:work) do
    AtlasRb::Work.create(collection.id, "#{fixtures}/work-mods.xml", depositor: depositor.nuid, nuid: '000000004')
  end
  let(:showcases) { Current.set(nuid: '000000004') { ShowcaseProvisioner.call(community_id: community.id) } }

  let(:depositor) do
    User.new(email: 'depositor@example.com', password: 'password', nuid: '000000002',
             name: 'Doe, Jane', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end
  let(:admin) do
    User.new(email: 'admin@example.com', password: 'password', nuid: '000000004', role: 'admin', groups: [])
  end

  # Showcases take their community's read ACL when they are created, so the
  # ancestry goes public first, then the showcases are provisioned.
  before do
    publicize_ancestry!(community: community, collection: collection)
    AtlasRb::Resource.set_permissions(work.id, { 'read' => ['public'], 'edit' => [Permissions::STAFF_EDIT_GROUP] },
                                      nuid: '000000004')
    AtlasRb::System::Work.add_linked_member(work.id, showcases['Datasets'].id, on_behalf_of: depositor.nuid)
    # An unfinished deposit sends its depositor to the metadata page, not Edit.
    AtlasRb::Work.complete(work.id, nuid: '000000004')
  end

  def submit(genre)
    patch work_path(work.id), params: { work: { title: 'A river runs past the field', showcase_genre: genre } }
  end

  def linked
    Array(AtlasRb::Work.linked_members(work.id, nuid: '000000004'))
  end

  it 'offers the depositor the choice, with the current genre selected' do
    sign_in depositor
    get edit_work_path(work.id)

    expect(response.body).to include('Showcase category', 'This work is published in the “Datasets” showcase.')
    expect(response.body).to match(/<option selected="selected" value="Datasets">/)
  end

  # Staff load theses, so a depositor is never offered that genre.
  it 'does not offer a depositor the staff-only genre' do
    sign_in depositor
    get edit_work_path(work.id)

    expect(response.body).to include('value="Presentations"')
    expect(response.body).not_to include('value="Theses &amp; Dissertations"')
  end

  it "moves the depositor's Work to the chosen showcase, in one step" do
    sign_in depositor
    submit('Presentations')

    expect(flash[:notice]).to eq('Moved to the “Presentations” showcase.')
    expect(linked).to include(showcases['Presentations'].id)
    expect(linked).not_to include(showcases['Datasets'].id)
    expect(AdminNotice.last).to have_attributes(kind: 'showcase_promotion', subject_noid: work.id)
  end

  it "lets an admin move a depositor's Work" do
    sign_in admin
    submit('Presentations')

    expect(linked).to include(showcases['Presentations'].id)
    expect(linked).not_to include(showcases['Datasets'].id)
  end

  it 'leaves the showcase alone when the category is unchanged' do
    sign_in depositor
    expect { submit('Datasets') }.not_to change(AdminNotice, :count)

    expect(linked).to include(showcases['Datasets'].id)
  end

  it 'refuses a staff-only genre a depositor sends by hand' do
    sign_in depositor
    submit('Theses & Dissertations')

    expect(flash[:alert]).to eq('The showcase category was not changed.')
    expect(linked).to include(showcases['Datasets'].id)
  end
end
