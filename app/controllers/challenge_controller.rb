class ChallengeController < ApplicationController
  skip_before_filter :verify_authenticity_token, only: :verify
  layout false

  def verify
    token  = params["cf-turnstile-response"].to_s
    target = sanitize_target(params[:redirect_url].to_s)

    if token.empty?
      return render(text: "missing token", status: 400)
    end

    unless same_origin?(request.env["HTTP_ORIGIN"] || request.env["HTTP_REFERER"])
      Rails.logger.warn("[turnstile] bad origin ip=#{request.remote_ip} origin=#{request.env['HTTP_ORIGIN'].inspect} referer=#{request.env['HTTP_REFERER'].inspect}")
      return render(text: "bad origin", status: 403)
    end

    result = Cerberus::TurnstileVerifier.verify(token, request.remote_ip)

    if result.success?
      Rails.logger.info("[turnstile] pass ip=#{request.remote_ip} target=#{target}")
      redirect_to(target, status: 302)
    else
      Rails.logger.warn("[turnstile] fail ip=#{request.remote_ip} codes=#{result.error_codes.inspect} soft_fail=#{result.soft_fail}")
      render text: "Verification failed. Please sign in via Shibboleth (http://repository.library.northeastern.edu/users/auth/shibboleth) or contact Library-Repository-Team@neu.edu.",
             status: 403
    end
  end

  private

  def sanitize_target(url)
    return root_path if url.blank?
    uri = URI(url) rescue nil
    return root_path unless uri
    return root_path unless uri.host.nil? || uri.host == request.host
    uri.request_uri
  end

  def same_origin?(header)
    return true if header.blank?
    origin_host = URI(header).host rescue nil
    origin_host == request.host
  end
end
