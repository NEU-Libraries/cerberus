class ImpressionProcessingJob
  def queue_name
    :impression_processing
  end

  def run
    # Only process what hasn't been done already
    Impression.where(processed: false).find_each do |imp|
      ua = imp.user_agent.downcase
      botlist = I18n.t("bots").map(&:downcase)

      if !botlist.any?{|s| ua.include?(s)} && !low_filter.any?{|s| ua == s }
        imp.public = true
      end

      imp.processed = true
      imp.save!
    end

  end

end
