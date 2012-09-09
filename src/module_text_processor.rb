#require 'lingua/stemmer'

module TextProcessor
  # Returns a set of character `n`-grams computed from this string.
  def to_ngrams(n)
    self.normalize_tweet.scan(/.{#{n}}/)
  end
# Returns a set of character `n`-grams computed from this string.
  def to_ngram_words(n)
    self.normalize_tweet.scan(/^(\w+\s+?\w+\s+?\w+)$/)
  end
  # TODO: Try not normalizing out all non-ASCII characters! Should significantly reduce false positive rate.
  def normalize_tweet
    self.remove_tweeters.remove_links.remove_hashtags.downcase.gsub(/\s/, " ")
  end
  def normalize
    self.strip.remove_line_feeds.remove_words_starting_with("$").remove_words_starting_with("#").remove_words_starting_with("@").remove_words_starting_with("&").remove_links.remove_words_whose_length_is_less_than(3).downcase
  end
#  def stem_all_words
#    if self.word_count > 1
#      return Lingua.stemmer(self.scan(/\w+/), :language => "en", :encoding => "UTF_8" ).join(" ")
#    else
#      return Lingua.stemmer(self.scan(/\w+/), :language => "en", :encoding => "UTF_8" )
#    end
#  end
  def remove_reserved_chars
    self.gsub(/[^[:alnum:]| ]/, '')
  end
  # Remove mentions of other twitter users.
  def remove_tweeters
    self.remove_words_starting_with "@"
  end

  # Remove any words beginning with '#'.
  def remove_hashtags
    self.remove_words_starting_with "#"
  end

  # Remove any words beginning with '#'.
  def remove_dollar
    self.remove_words_starting_with "$"
  end

  def remove_words_starting_with(tag)
    tag = "\\" + tag if tag[0] ==  "$"
    self.gsub(/#{tag}\w+/, "")
  end

  def remove_non_printable_characters
    self.scan(/[[:print:]]/).join
  end

  def remove_links
    self.gsub(/https?:\/\/[\S]+/, "")
  end

  def remove_stop_words(lowercase_stop_words)
    self.downcase.gsub(/\b(#{lowercase_stop_words.join('|')})\b/mi, '')
  end

  def remove_words_whose_length_is_less_than(minimum_word_length)
    self.scan(/\w+/).select{|w| w.length >= minimum_word_length}.join(' ')
  end

  def remove_line_feeds
    self.gsub(/\r|\n/, " ")
  end

  def word_count
    self.scan(/(\w|-)+/).size
  end
end