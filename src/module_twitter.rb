require 'twitter'

module TwitterFunctions

  @@TWITTER_API_RATE_LIMIT_SEC = 28
  def TwitterFunctions.log_message(msg)
    #puts msg
  end
  def TwitterFunctions.process_search(positive, search_text, items_per_page, max_hours_back)

    last_tweet = nil

    search = positive ? Twitter::Search.new.positive : Twitter::Search.new.negative

    last_tweet_datetime = DateTime.now().advance(:hours => max_hours_back)

    begin

      log_message "Searching Postive:#{positive}, Query: #{search_text}, Max Hours: #{max_hours_back}"

          search = positive ? Twitter::Search.new.positive : Twitter::Search.new.negative

          search.containing(search_text)

          search.max_id(last_tweet.id - 1)  unless last_tweet.nil?

          has_page = false

          search.per_page(items_per_page)

          results = search.fetch

          begin

            last_tweet = results.nil? ? nil : results.last

            yield results if block_given? && !last_tweet.nil?

            #get next page if we can if now exit whlle
            begin

              has_page =  search.next_page?

              results = search.fetch_next_page if has_page

            rescue Exception => e

               has_page = false

            end

          end while has_page

    end while !last_tweet.nil? && (DateTime.parse(last_tweet.created_at) > last_tweet_datetime)

  end
  def TwitterFunctions.get_client(token=nil, secret=nil)
    client = nil

    if token.nil? || secret.nil?
      client = Twitter::Client.new
    else
      client = Twitter::Client.new(:oauth_token => token, :oauth_token_secret => secret)
    end

    client

  end

  def TwitterFunctions.process_search_all(search_text, items_per_page, max_hours_back)

    if search_text.start_with? "@"
      TwitterFunctions.user_time_line(get_client, search_text, items_per_page, max_hours_back) do |results|
        yield results if block_given?
      end
    else
      search(get_client, search_text, items_per_page, max_hours_back) do | results |
        yield results if block_given?
      end
    end
  end
  def TwitterFunctions.user_time_line(client, search_text, items_per_page, max_hours_back)

    page_count = 3200/items_per_page

    log_message "Searching All Public Tweets posted by user: #{search_text}, Max Hours: #{max_hours_back}"

    (1..page_count).each do |page|

      begin

        yield Twitter.user_timeline(search_text, :count=>items_per_page, :page=>page) if block_given?

      rescue

      end

    end
  end
  def TwitterFunctions.search(client, search_text, items_per_page, max_hours_back)

    last_tweet = nil
    total_tweet_count = 0

    search = Twitter::Search.new

    last_tweet_datetime = DateTime.now().advance(:hours => max_hours_back)
    log_message "Searching All Public Tweets, Query: #{search_text}, Max Hours: #{max_hours_back}"
    begin

      search.clear

      search.containing(search_text)

      search.max_id(last_tweet.id - 1)  unless last_tweet.nil?

      has_page = false

      search.per_page(items_per_page)
      begin

        results = search.fetch

        begin

          last_tweet = results.nil? ? nil : results.last

          total_tweet_count += results.nil? ? 0 : results.count

          yield results if block_given? && !last_tweet.nil?

          #get next page if we can if now exit whlle
          begin

            has_page =  search.next_page?

            results = search.fetch_next_page if has_page

          rescue Exception => e

             has_page = false

          end

        end while has_page

        log_message "Total Tweets Found: #{total_tweet_count}, last tweet: #{last_tweet.id  unless last_tweet.nil?}, last tweet Date: #{last_tweet.created_at  unless last_tweet.nil?}"

        limit_api_calls

      rescue Twitter::Error => srv_e

       log_message "Twitter Service Error #{srv_e.message} will retry in #{srv_e.retry_after} seconds"

       sleep(srv_e.retry_after)

      rescue Exception => e

        log_message e.message

      end


    end while !last_tweet.nil? && (DateTime.parse(last_tweet.created_at) > last_tweet_datetime)

  end

  def TwitterFunctions.limit_api_calls

    rate_limit = Twitter.rate_limit_status
    if rate_limit["remaining_hits"] == "0"

      remaining_sec = Time.now.to_i - rate_limit["reset_time_in_secs"]

      if remaining_sec > 0
        log_message "Rate limit hit - sleeping for #{remaining_sec} seconds"
        sleep(remaining_sec)
      end

    else
      log_message "API rate limiting - sleeping for #{@@TWITTER_API_RATE_LIMIT_SEC} seconds"
      sleep(@@TWITTER_API_RATE_LIMIT_SEC)
    end
  end

end