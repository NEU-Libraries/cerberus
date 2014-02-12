require 'spec_helper'

describe "ImpressionCount" do 
  class ImpTest
    include Drs::ImpressionCount
    attr_accessor :pid

    def initialize(pid) 
      self.pid = pid 
    end
  end

  let(:imp) { ImpTest.new("1") }

  it "Returns zero impressions when none have been recorded" do 
    imp.impression_count.should == 0 
  end

  it "Returns a single impression when one has been recorded" do 
    DrsImpression.create(pid: "1", session_id: "abc") 

    imp.impression_count.should == 1 
  end

  it "Knows how to distinguish between impressions" do 
    DrsImpression.create(pid: "1", session_id: "def")
    DrsImpression.create(pid: "1", session_id: "ghi") 
    DrsImpression.create(pid: "2", session_id: "def") 

    imp.impression_count.should == 2 
  end
end