# frozen_string_literal: true

# Self-service account switching. A person's NUID can hold several accounts
# (their staff/student logins), each with its own group set; this lets them act
# as a different one of *their own* accounts without logging out, and choose a
# preferred (default) one. Both actions are constrained to the caller's own
# accounts — Atlas independently rejects a foreign account (a 403 on the switch
# read, a 404 on set-preferred), so the membership check here is the Cerberus
# half of a two-sided guarantee, not the only one.
class AccountsController < ApplicationController
  before_action :require_account_user

  # A transport/parse failure reaching Atlas shouldn't 500 the switcher — the
  # accounts lookup, the switch login, and set-preferred all cross the wire.
  rescue_from Faraday::Error, JSON::ParserError, with: :atlas_unavailable

  # Re-hydrate the session identity as one of the caller's other accounts. Email
  # is the account key; login rides it as a signed `acct` claim, so the whole
  # session (groups, role, affiliation) becomes that account's.
  def switch
    email = params[:email].to_s
    return reject('That account is not one of yours.') unless own_account?(email)

    values = AtlasRb::Authentication.login(current_user.nuid, email: email)
    sign_in(User.new(email: values.email, nuid: values.nuid, name: values.name,
                     groups: values.groups, role: values.role, affiliation: values.affiliation))
    redirect_to my_drs_path, notice: "Switched to #{email}."
  end

  # Set the caller's preferred (default) account — the one a future login lands
  # on when it names none.
  def prefer
    email = params[:email].to_s
    return reject('That account is not one of yours.') unless own_account?(email)

    AtlasRb::User.set_preferred(current_user.nuid, email: email, nuid: current_user.nuid)
    redirect_to my_drs_path, notice: "#{email} is now your preferred account."
  end

  private

    def require_account_user
      redirect_to(root_path, alert: 'Sign in to manage your accounts.') unless current_user&.nuid
    end

    # Guard both actions against a forged email: only ever switch to / prefer an
    # account that is actually one of the caller's.
    def own_account?(email)
      email.present? && my_account_emails.include?(email)
    end

    def my_account_emails
      AtlasRb::User.accounts(current_user.nuid, nuid: current_user.nuid)['accounts'].map { |a| a['email'] }
    end

    def reject(message)
      redirect_back(fallback_location: my_drs_path, alert: message)
    end

    def atlas_unavailable(error)
      Rails.logger.error("Account action failed: #{error.class} #{error.message}")
      redirect_to(my_drs_path, alert: 'Something went wrong reaching your accounts. Please try again.')
    end
end
