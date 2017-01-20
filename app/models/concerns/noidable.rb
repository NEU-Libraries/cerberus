module Noidable
  def assign_id
    noid_service.mint
  end

  private

    def noid_service
      @noid_service ||= ActiveFedora::Noid::Service.new
    end
end
