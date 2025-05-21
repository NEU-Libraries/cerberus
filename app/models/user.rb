# frozen_string_literal: true

class User < ApplicationRecord
  devise :custom_authenticatable, authentication_keys: [:email, :password]
end
