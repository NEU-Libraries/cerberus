# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.inline!

RSpec.describe WorkCreator do
  let(:work) { FactoryBot.create_for_repository(:work) }
  let!(:file_set) { FactoryBot.create_for_repository(:file_set, :word, work: work, a_member_of: work.id) }

  describe '#call' do
    it 'creates a pdf derivative from a word binary' do
      expect(work.children.count).to eq(2)
      expect(work.children.map { |fs| fs.type }.sort).to eq([Classification.descriptive_metadata.name, Classification.text.name].sort)

      DerivativeCreator.call(work_id: work.id, file_id: file_set.files.first.file_identifiers.first.to_s, file_path: 'example.docx')
      expect(work.reload.children.count).to eq(3)
      expect(work.children.map { |fs| fs.type }.sort).to eq([Classification.descriptive_metadata.name, Classification.text.name, Classification.derivative.name].sort)

      # find the derivative file set, check that the binary exists
      derivative_file_set = work.children.find { |fs| fs.type == Classification.derivative.name }
      expect(derivative_file_set.files.first.file_identifiers.count).to eq(1)
    end
  end
end
