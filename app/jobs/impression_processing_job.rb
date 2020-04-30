class ImpressionProcessingJob
  def queue_name
    :impression_processing
  end

  def run
    # bot list
    # do IP sweep - greater than 150 downloads OR views in 24hr period (cron) == bot
    # add to temporary bot list for this job
    # public false, processed true

    results = Impression.where(processed: false)
    count_hsh = results.each_with_object(Hash.new {|h, k| h[k] = Hash.new(0) }) { |imp,counts| counts[imp.ip_address][imp.action] += 1}
    offenders = count_hsh.select{ |k,v| (v["view"].present? && v["view"] > 150) || (v["download"].present? && v["download"] > 150) }
    bot_ip_list = offenders.map {|k,v| k}

    # Load Balancer - VPN'd traffic seems to take on this IP
    # We'd like to keep these as they're fairly safe, and helpful
    bot_ip_list = bot_ip_list - ["155.33.16.26"]

    botlist = I18n.t("bots").map(&:downcase)

    # Only process what hasn't been done already
    Impression.where(processed: false).find_each do |imp|
      ua = imp.user_agent.downcase

      if !botlist.any?{|s| ua.include?(s)} && !bot_ip_list.include?(imp.ip_address)
        imp.public = true
      end

      imp.processed = true
      imp.save!
    end

  end

end
