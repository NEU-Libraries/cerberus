class Work < Hydra::Works::Work
  Hydra::Works::Work.include Mods
  Hydra::Works::Work.include Parentable
  Hydra::Works::Work.include Noidable
  Hydra::Works::Work.include Hydra::PCDM::ObjectBehavior
  Hydra::Works::Work.include Hydra::AccessControls::Permissions
end
