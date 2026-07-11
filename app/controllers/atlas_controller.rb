# frozen_string_literal: true

class AtlasController < ApplicationController
  def login; end

  def process_login
    sign_in_from_atlas(params[:user][:nuid])
  end

  def find_or_create; end

  def process_find_or_create
    attrs = find_or_create_params
    AtlasRb::System::User.find_or_create(**attrs)
    sign_in_from_atlas(attrs[:nuid])
  end

  def user
    @user = current_user
  end

  private

    def find_or_create_params
      {
        nuid:        params[:user][:nuid],
        name:        params[:user][:name].presence,
        email:       params[:user][:email].presence,
        affiliation: params[:user][:affiliation].presence,
        groups:      params[:user][:groups].to_s.split("\n").map(&:strip).compact_blank
      }
    end

    def sign_in_from_atlas(nuid)
      user_values = AtlasRb::Authentication.login(nuid)
      user = User.new(
        email:       user_values.email,
        nuid:        user_values.nuid,
        name:        user_values.name,
        groups:      user_values.groups,
        role:        user_values.role,
        affiliation: user_values.affiliation
      )
      sign_in(user)
      redirect_to root_path, notice: signed_in_notice(nuid)
    end

    # A person whose NUID holds more than one account lands on their preferred
    # one (the login above named no account), so nudge them toward My DRS to
    # switch or set a default; single-account users get the plain confirmation.
    def signed_in_notice(nuid)
      if multiple_accounts?(nuid)
        'You have more than one account. Switch between accounts or set a preferred one from My DRS.'
      else
        'You have successfully signed in.'
      end
    end

    # nuid is passed explicitly rather than read from Current: set_current_nuid
    # ran before sign_in, so Current.nuid is still the guest fallback here.
    def multiple_accounts?(nuid)
      AtlasRb::User.accounts(nuid, nuid: nuid)['accounts'].size > 1
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.error("Account lookup failed for #{nuid}: #{e.class} #{e.message}")
      false
    end
end
