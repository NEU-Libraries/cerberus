class GenerateDerivativesJob < ApplicationJob
  queue_as :default

  def perform(file_set_id)
    fs = Hydra::Works::FileSet.find(file_set_id)
    fs.create_derivatives
  end
end
