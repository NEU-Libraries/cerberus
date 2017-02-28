class Work < Hydra::Works::Work
  include Mods
  include Parentable
  include Noidable
  include Hydra::PCDM::ObjectBehavior
  include Hydra::AccessControls::Permissions
end
