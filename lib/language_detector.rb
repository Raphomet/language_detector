require 'yaml'

if RUBY_VERSION < '1.9'
  require 'jcode'
  $KCODE = 'u'
end

class LanguageDetector

  # Supports two ngram databases:
  # - fm - built from scratch texts included with gem
  # - tc - textcat ngram database
  def initialize(type='tc')
    @profiles = load_model(type)
  end

  def detect(text)
    p = LanguageDetector::Profile.new(:text => text)
    best_profile = nil
    best_distance = nil

    @profiles.each do |profile|
      distance = p.compute_distance(profile)

      if !best_distance or distance < best_distance
        best_distance = distance
        best_profile = profile
      end
    end
    #p best_distance
    best_profile.name
  end

  def self.train_tc
    profiles = []
    languages = Dir.glob("textcat_ngrams/*.lm").collect {|l| l.gsub(/\.lm$/,'')}.sort

    languages.each do |language|
      ngram = {}
      rang = 1

      lang = File.open("#{language}.lm", "r")
      lang.each_line do |line|

        line = line.chomp
        if line =~ /^[^0-9\s]+/o
          ngram[line.chomp.split(/\t/).first] = rang
          rang += 1
        end

      end
      lang.close

      p = LanguageDetector::Profile.new(:name => language.split('/').last.split('-').first)
      p.ngrams = ngram

      profiles.push p
    end

    puts 'saving model...'
    filename = File.expand_path(File.join(File.dirname(__FILE__), "model-tc.yml"))
    File.open(filename, 'w') {|f| YAML.dump(profiles, f)}
  end

  def self.train_fm
    # For a full list of ISO 639 language tags visit:
    # http://www.loc.gov/standards/iso639-2/englangn.html
    # http://www.loc.gov/standards/iso639-2/php/English_list.php

    #LARGE profiles follow:

    #NOTE: These profiles taken from the "World War II" node on wikipedia
    #with the 'lang' and ?action=raw URI which results in a UTF8 encoded
    #file.  If we need to get more profile data for a language this is
    #always a good source of data.
    #
    # http:#en.wikipedia.org/wiki/World_War_II
    # EU corpus: http://wt.jrc.it/lt/Acquis/
    # 

    training_data = [
      [ "ar", "ar-utf8.txt", "utf8", "arabic" ],
      [ "bg", "bg-utf8.txt", "utf8", "bulgarian" ],
      [ "cs", "cs-utf8.txt", "utf8", "czech" ],
      [ "da", "da-utf8.txt", "utf8", "danish" ],
      [ "de", "de-utf8.txt", "utf8", "german" ],
      [ "el", "el-utf8.txt", "utf8", "greek" ],
      [ "en", "en-utf8.txt", "utf8", "english" ],
      [ "et", "et-utf8.txt", "utf8", "estonian" ],
      [ "es", "es-utf8.txt", "utf8", "spanish" ],
      [ "fa", "fa-utf8.txt", "utf8", "farsi" ],
      [ "fi", "fi-utf8.txt", "utf8", "finnish" ],
      [ "fr", "fr-utf8.txt", "utf8", "french" ],
      [ "ga", "ga-utf8.txt", "utf8", "irish" ],
      [ "he", "he-utf8.txt", "utf8", "hebrew" ],
      [ "hi", "hi-utf8.txt", "utf8", "hindi" ],
      [ "hr", "hr-utf8.txt", "utf8", "croatian" ],
      [ "it", "it-utf8.txt", "utf8", "italian" ],
      [ "ja", "ja-utf8.txt", "utf8", "japanese" ],
      [ "ko", "ko-utf8.txt", "utf8", "korean" ],
      [ "hu", "hu-utf8.txt", "utf8", "hungarian" ],
      [ "tk", "tk-utf8.txt", "utf8", "turkish" ],
      [ "nl", "nl-utf8.txt", "utf8", "dutch" ],
      [ "no", "no-utf8.txt", "utf8", "norwegian" ],
      [ "pl", "pl-utf8.txt", "utf8", "polish" ],
      [ "pt", "pt-utf8.txt", "utf8", "portuguese" ],
      [ "ro", "ro-utf8.txt", "utf8", "romanian" ],
      [ "ru", "ru-utf8.txt", "utf8", "russian" ],
      [ "sl", "sl-utf8.txt", "utf8", "slovenian" ],
      [ "sv", "sv-utf8.txt", "utf8", "swedish" ],
      [ "th", "th-utf8.txt", "utf8", "thai" ],
      [ "uk", "uk-utf8.txt", "utf8", "ukraninan" ],
      [ "vi", "vi-utf8.txt", "utf8", "vietnamese" ],
      [ "zh", "zh-utf8.txt", "utf8", "chinese" ]
      # id (indonesian)
      # ku (kurdish)
      # lt (lithuanian)
      # lv (latvian)
      # mk (macedonian)
      # ms (malay)
      # sr (serbian)
      # my (burmese)
      # [ "fy", "fy-utf8.txt", "utf8", "frisian" ],
      # [ "io", "io-utf8.txt", "utf8", "ido" ],
      # [ "is", "is-utf8.txt", "utf8", "icelandic" ],
    ]

    profiles = []
    training_data.each do |data|
      p = LanguageDetector::Profile.new(:name => data.last, :file => data[1])
      profiles.push p
    end

    puts 'saving model...'
    filename = File.expand_path(File.join(File.dirname(__FILE__), "model-fm.yml"))
    File.open(filename, 'w') {|f| YAML.dump(profiles, f)}
  end

  def load_model(name)
    filename = File.expand_path(File.join(File.dirname(__FILE__), "model-#{name}.yml"))
    @profiles = YAML.load_file(filename)
  end
end

class LanguageDetector::Profile
  LIMIT = 1500
  PUNCTUATION_REGEX = /[\W^_\d]+/
  attr_accessor :ngrams, :name

  def initialize(*args)
    args = args.first

    @name = args[:name] || ""
    @ngrams = {}

    init_with_string(args[:text]) if args[:text]
    init_with_file(args[:file]) if args[:file]
  end

  def compute_distance(other_profile)
    distance = 0
    other_profile.ngrams.each do |k, v|
      n = @ngrams[k]
      if n = @ngrams[k]
        distance += (v - n).abs
      else
        distance += LIMIT
      end
    end

    distance
  end

  def init_with_file(filename)
    ngram_count = Hash.new(0)

    path = File.expand_path(File.join(File.dirname(__FILE__), "training_data/" + filename))
    File.open(path).each_line {|line| generate_ngrams(line, ngram_count) }
    puts "training with " + path

    ngram_count.sort {|a,b| b[1] <=> a[1]}.each_with_index do |t, i|
      ngrams[t[0]] = (i+1)
      break if i > LIMIT
    end
  end

  def init_with_string(str)
    ngram_count = {}
    generate_ngrams(str, ngram_count)

    ngram_count.sort {|a,b| b[1] <=> a[1]}.each_with_index do |t, i|
      @ngrams[t[0]] = (i+1)
      break if i > LIMIT
    end
  end
  
  def generate_ngrams(str, ngram_count)
    tokens = tokenize(str)
    tokens.each do |token|
      2.upto(5) { |n| count_ngram(token, n, ngram_count) }
    end
  end

  def tokenize(str) str.split(PUNCTUATION_REGEX); end
  def is_punctuation?(char); char =~ PUNCTUATION_REGEX; end

  def count_ngram(token, n, counts)
    token = "_#{token}#{'_' * (n-1)}" if n > 1 && token.length >= n
    
    n.upto(token.length).with_index do |t, i|
      s = ''

      0.upto(n-1) { |j| s << token[i+j] }
      counts[s] = counts.has_key?(s) ? counts[s]+=1 : 1
    end

    counts
  end
end

if $0 == __FILE__
  if ARGV.length == 1
    if 'train-fm' == ARGV[0]
      LanguageDetector.train_fm
    elsif 'train-tc' == ARGV[0]
      LanguageDetector.train_tc
    end
  else
    d = LanguageDetector.new()
    p d.detect("what language is this? can you guess? That's a hard question")
  end
end
