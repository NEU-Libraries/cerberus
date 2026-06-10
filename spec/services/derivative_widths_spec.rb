# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeWidths do
  def result_for(raw, longest_edge: 588)
    described_class.call(raw: raw, longest_edge: longest_edge)
  end

  it 'accepts a single enabled size' do
    result = result_for({ 'small' => '149' })
    expect(result).to be_valid
    expect(result.widths).to eq(small: 149)
  end

  it 'accepts small + large with medium skipped (each size is optional)' do
    result = result_for({ 'small' => '149', 'large' => '503' })
    expect(result).to be_valid
    expect(result.widths).to eq(small: 149, large: 503)
  end

  it 'accepts the full strictly-increasing trio as symbol-keyed Integers' do
    result = result_for({ 'small' => '100', 'medium' => '200', 'large' => '300' })
    expect(result.widths).to eq(small: 100, medium: 200, large: 300)
  end

  it 'accepts a value equal to the longest edge' do
    expect(result_for({ 'large' => '588' })).to be_valid
  end

  it 'treats empty input as valid with no widths' do
    result = result_for({})
    expect(result).to be_valid
    expect(result.widths).to eq({})
  end

  it 'treats blank values as unchecked' do
    result = result_for({ 'small' => '149', 'medium' => '', 'large' => ' ' })
    expect(result.widths).to eq(small: 149)
  end

  it 'ignores unknown keys' do
    expect(result_for({ 'small' => '10', 'huge' => '999' }).widths).to eq(small: 10)
  end

  it 'rejects non-increasing sizes with the ordering message' do
    result = result_for({ 'small' => '200', 'medium' => '200' })
    expect(result).not_to be_valid
    expect(result.error).to eq('Sizes must increase from small to medium to large.')

    expect(result_for({ 'small' => '300', 'large' => '100' })).not_to be_valid
  end

  it 'rejects zero, negatives, fractions, and junk with the range message' do
    ['0', '-5', '1.5', 'abc'].each do |bad|
      result = result_for({ 'small' => bad })
      expect(result).not_to be_valid, "expected #{bad.inspect} to be rejected"
      expect(result.error).to include('whole number between 1 and 588 pixels')
    end
  end

  it 'rejects values above the longest edge' do
    result = result_for({ 'large' => '589' })
    expect(result).not_to be_valid
    expect(result.error).to include("the master image's longest edge")
  end
end
