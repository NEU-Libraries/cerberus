# frozen_string_literal: true

require 'rails_helper'

describe StructuralContainers do
  # A host that records crumbs as [title, path] pairs. #breadcrumbs stands in for
  # ApplicationController's community trail, which reads Atlas.
  let(:host_class) do
    Class.new do
      include Rails.application.routes.url_helpers
      include StructuralContainers

      attr_reader :crumbs

      def initialize
        @crumbs = []
      end

      def breadcrumb(title, path, **) = @crumbs << [title, path]
      def breadcrumbs(noid, **) = @crumbs << ["community #{noid}", "/communities/#{noid}"]
      def add_breadcrumb_for(noid, klass, title, **) = @crumbs << [title, "#{klass}:#{noid}"]
    end
  end

  let(:host) { host_class.new }

  let(:people)  { { 'noid' => 'people', 'klass' => 'Community', 'title' => 'People', 'system_container' => true } }
  let(:root)    { { 'noid' => 'janeroot', 'klass' => 'Collection', 'title' => 'Personal Root', 'personal_root' => true } }
  let(:coastal) { { 'noid' => 'coastal', 'klass' => 'Collection', 'title' => 'Coastal Research' } }
  let(:jane) do
    SolrDocument.new('noid_ssi' => 'janenoid', 'display_name_ssi' => 'Jane Doe',
                     'affiliated_community_ids_ssim' => ['libnoid'])
  end

  def trail(ancestors, item: nil)
    host.send(:ancestor_trail, ancestors, item: item)
    host.crumbs
  end

  describe '#ancestor_trail' do
    it "replaces People / Personal Root with the owner's profile trail, at any depth" do
      allow(host).to receive(:personal_root_owner).with('janeroot').and_return(jane)

      expect(trail([people, root, coastal])).to eq(
        [['community libnoid', '/communities/libnoid'],
         ['Faculty & Staff', '/communities/libnoid/people'],
         ['Jane Doe', '/people/janenoid'],
         ['Coastal Research', 'Collection:coastal']]
      )
    end

    it 'leads with People when the owner has no affiliation' do
      unaffiliated = SolrDocument.new('noid_ssi' => 'janenoid', 'display_name_ssi' => 'Jane Doe')
      allow(host).to receive(:personal_root_owner).with('janeroot').and_return(unaffiliated)

      expect(trail([people, root]).map(&:first)).to eq(['People', 'Jane Doe'])
    end

    it 'still drops the structural entries when the owner cannot be found' do
      allow(host).to receive(:personal_root_owner).and_return(nil)

      expect(trail([people, root, coastal]).map(&:first)).to eq(['Coastal Research'])
    end

    it 'leads with the owner when the item is the personal root itself' do
      item = AtlasRb::Mash.new('id' => 'janeroot', 'personal_root' => true)
      allow(host).to receive(:personal_root_owner).with('janeroot').and_return(jane)

      expect(trail([people], item: item).map(&:first)).to eq(['community libnoid', 'Faculty & Staff', 'Jane Doe'])
    end

    it 'keeps an ordinary chain as it is, without looking for an owner' do
      nu = { 'noid' => 'nu', 'klass' => 'Community', 'title' => 'Northeastern University' }
      expect(Blacklight.default_index).not_to receive(:search)

      expect(trail([nu, coastal]).map(&:first)).to eq(['Northeastern University', 'Coastal Research'])
    end
  end

  describe 'the Solr reads' do
    let(:index) { instance_double(Blacklight::Solr::Repository) }

    before { allow(Blacklight).to receive(:default_index).and_return(index) }

    it "finds the owner by the root's NOID, not by any depositor" do
      response = instance_double(Blacklight::Solr::Response, documents: [jane])
      expect(index).to receive(:search)
        .with(hash_including(fq: ['internal_resource_tesim:Person', 'personal_root_id_ssi:"janeroot"']))
        .and_return(response)

      expect(host.send(:personal_root_home, 'janeroot')).to eq('/people/janenoid')
    end

    it 'sends a root with no owner to the People directory' do
      allow(index).to receive(:search).and_return(instance_double(Blacklight::Solr::Response, documents: []))

      expect(host.send(:personal_root_home, 'orphan')).to eq('/people')
    end

    it 'recognises the People Community by its Solr flag' do
      expect(index).to receive(:search)
        .with(hash_including(fq: ['system_container_bsi:true', 'alternate_ids_tesim:people']))
        .and_return(instance_double(Blacklight::Solr::Response, total: 1))

      expect(host.send(:system_container?, 'people')).to be(true)
    end
  end
end
