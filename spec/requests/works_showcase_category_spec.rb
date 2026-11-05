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
    notice = AdminNotice.last
    expect(notice).to have_attributes(kind: 'showcase_promotion', subject_noid: work.id)
    expect(notice.detail(:genre)).to eq('Presentations')
    expect(notice.detail(:community_name)).to be_present
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

  # Faculty in two departments: the Work sits in both communities' showcases,
  # always under the one category it has.
  context 'when the Work is in two communities' do
    let(:art) { AtlasRb::Community.create(nil, "#{fixtures}/community-mods.xml", nuid: '000000004') }
    let(:art_showcases) { Current.set(nuid: '000000004') { ShowcaseProvisioner.call(community_id: art.id) } }

    before do
      publicize_ancestry!(community: art)
      AtlasRb::System::Work.add_linked_member(work.id, art_showcases['Datasets'].id, on_behalf_of: depositor.nuid)
    end

    it 'lists both communities, each with its own Remove' do
      sign_in depositor
      get edit_work_path(work.id)

      rows = response.parsed_body.css('.showcase-placements__row')
      expect(rows.size).to eq(2)
      expect(rows.map { |row| row.at_css('button')['value'] })
        .to contain_exactly(showcases['Datasets'].id, art_showcases['Datasets'].id)
      expect(response.body).to include('Choose another category to move it there in every community.')
    end

    it 'moves the Work to the new category in both communities' do
      sign_in depositor
      submit('Presentations')

      expect(flash[:notice]).to eq('Moved to the “Presentations” showcase.')
      expect(linked).to include(showcases['Presentations'].id, art_showcases['Presentations'].id)
      expect(linked).not_to include(showcases['Datasets'].id, art_showcases['Datasets'].id)
    end

    it 'removes the Work from one community and leaves it in the other' do
      sign_in depositor

      expect { delete showcase_work_path(work.id), params: { showcase_id: art_showcases['Datasets'].id } }
        .to change(AdminNotice, :count).by(1)

      expect(response).to redirect_to(edit_work_path(work.id))
      expect(linked).not_to include(art_showcases['Datasets'].id)
      expect(linked).to include(showcases['Datasets'].id)
      expect(AdminNotice.last.detail(:outcome)).to eq('removed')
    end
  end

  # Only the depositor or an admin may act on the Work's showcases.
  it 'refuses a removal from someone who is neither depositor nor admin' do
    other = User.new(email: 'other@example.com', password: 'password', nuid: '000000006',
                     name: 'Williams, Susan', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
    sign_in other

    delete showcase_work_path(work.id), params: { showcase_id: showcases['Datasets'].id }

    expect(flash[:alert]).to eq(WorkShowcaseCategory::SHOWCASE_REMOVE_REFUSED)
    expect(linked).to include(showcases['Datasets'].id)
  end
end
