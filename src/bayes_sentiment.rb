require 'classifier'
require 'cmath'


 class BayesSentiment

 :public
   def initialize(positive_words, negative_words, neutral_words, stop_words)
      super

      @classifier = Classifier::Bayes.new 'positive', 'negative', 'neutral'

      positive_words.each {|x|@classifier.train 'positive', x}
      negative_words.each {|x|@classifier.train 'negative', x}
      neutral_words.each  {|x|@classifier.train 'neutral', x}

     @stop_words = /(#{stop_words.join(' |')})/

   end

   def sentiment(textString)

     result=[]

     begin
       textString = remove_stop_words(textString.downcase)
       result = @classifier.classifications(textString)
       result = [result['Positive'], result['Negative'], result['Neutral']]

     rescue => e

     end

     return result
   end

   def generate_sentiment_from_tweets(feed, tweets)

    sent = nil

    if tweets


      @dataPositive = []
      @dataNegative = []

      sent = feed.sentiments.new
      sent.negative = 0
      sent.positive = 0
      sent.positive_volume = 0
      sent.negative_volume = 0

      tweets.each do |t|

        s = sentiment(t.text)

        sent.negative += s[0]
        sent.positive += s[1]
        sent.positive_volume += 1
        sent.negative_volume += 1

        @dataPositive << [DateTime.parse(t.created_at), s[0]] unless s.nil?

        @dataNegative << [t.created_at, s[1]] unless s.nil?

      end

      sent.negative = sent.negative / sent.negative_volume
      sent.positive = sent.positive / sent.positive_volume

    end

    sent

   end
   def remove_stop_words(lowercase_string)
    return lowercase_string.gsub(@stop_words, '')
   end
 end