# frozen_string_literal: true

class Resource < Valkyrie::Resource
  include Relationships

  attribute :alternate_ids,
            Valkyrie::Types::Set.of(Valkyrie::Types::ID).meta(ordered: true).default {
              [Valkyrie::ID.new(Minter.mint)]
            }

  enable_optimistic_locking

  def noid
    alternate_ids.first.to_s
  end

  def to_param
    noid
  end

  def reload
    Resource.find(id)
  end

  def decorate
    ActiveDecorator::Decorator.instance.decorate(self)
  end
end
