class JsonWebToken
  def self.encode(payload)
    JWT.encode(payload, ENV["JWT_KEY_BASE"], 'HS256')
  end

  def self.decode(token)
    return HashWithIndifferentAccess.new(JWT.decode(token, ENV["JWT_KEY_BASE"], true, { algorithm: 'HS256' })[0])
  rescue
    nil
  end
end
