# frozen_string_literal: true

# The User Inbox. Everything here is scoped to the signed-in, non-guest
# user: the inbox query covers messages addressed to their NUID or any of
# their session groups (read-time group delivery — see Message.inbox_for),
# so addressing is also the authorization.
class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_messageable_user
  before_action :set_message, only: %i[show destroy]

  def index
    @messages = Message.inbox_for(current_user).page(params[:page])
    @receipts = MessageReceipt.where(nuid: current_user.nuid, message_id: @messages.map(&:id))
                              .index_by(&:message_id)
    @sender_names = NuidResolver.names_for(@messages.map(&:sender_nuid))
  end

  def show
    MessageReceipt.mark_read!(@message, current_user.nuid)
    @sender_names = NuidResolver.names_for([@message.sender_nuid])
  end

  def new
    @message = Message.new
  end

  def create
    @message = Message.new(message_params.merge(sender_nuid: attributed_nuid))
    if @message.save
      redirect_to messages_path, notice: 'Message sent.'
    else
      render :new, status: :unprocessable_content
    end
  end

  # Per-recipient soft-dismiss — the row stays for other recipients of a
  # group message; only this user's inbox hides it.
  def destroy
    MessageReceipt.dismiss!(@message, current_user.nuid)
    redirect_to messages_path, notice: 'Message dismissed.'
  end

  # Typeahead JSON for the compose form. Atlas's directory excludes
  # guest/anonymous/system roles server-side and caps results at 10.
  def recipients
    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    results = AtlasRb::User.search(query, nuid: current_user.nuid)
    render json: results.map { |user| { nuid: user['nuid'], name: NuidResolver.prettify(user['name']) } }
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.error("MessagesController#recipients: #{e.class} #{e.message}")
    render json: []
  end

  private

    def set_message
      @message = Message.inbox_for(current_user).find_by(id: params[:id])
      render template: 'errors/not_found', status: :not_found, layout: 'application' if @message.nil?
    end

    def require_messageable_user
      return if current_user&.messageable?

      render template: 'errors/forbidden', status: :forbidden, layout: 'application'
    end

    def message_params
      params.require(:message).permit(:subject, :body, :recipient_nuid, :recipient_group)
    end
end
