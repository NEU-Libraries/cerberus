class ImpressionProcessingJob
  def queue_name
    :impression_processing
  end

  def run
    # Low pass
    all_uas = Impression.pluck(:user_agent)
    ua_count = Hash.new(0)

    all_uas.each do |ua|
      ua_count[ua.downcase] += 1
    end

    low_filter_hsh = ua_count.select{|k,v| v < 10}
    low_filter_hsh = Hash[low_filter_hsh.sort_by{|k, v| v}]
    low_filter = low_filter_hsh.map {|k,v| k}

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
