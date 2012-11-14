module Clipster
  class Clip < ActiveRecord::Base
    include ActionView::Helpers::DateHelper

    before_create :default_values

    attr_accessible :clip, :language, :title, :private, :expires, :lifespan
    cattr_reader :lifespans

    belongs_to :user, :class_name => Clipster.config.user_class.to_s unless not Clipster.config.associates_clip_with_user

    self.primary_key = :url_hash

    # Define all supported lifespans and their time offset
    @@lifespans = {"Forever" => nil,
                   "An Hour" => {:hours=>1},
                   "A Week"  => {:days=>7},
                   "A Day"   => {:days=>1},
                   "A Month" => {:months=>1},
                   "A Year"  => {:years=>1}}

    # TODO: build more powerful search term creation
    scope :search, lambda {|term|
      where("(title LIKE :term or language LIKE :term or clip LIKE :term) and (expires is null OR expires > :now)",{
          :term => term,
          :now => DateTime.now
      })
    }

    # All clips that are public, language specific, and not expired
    scope :language_for_public, lambda {|lang|
      where("private = :private AND
             language = :lang AND
             (expires is null OR expires > :now)",{
          :private => false,
          :lang => lang,
          :now  => DateTime.now
      })
    }

    # All clips that are public, and not expired
    scope :public, lambda {
      where("private = :private AND
             (expires is null OR expires > :now)",{
          :private => false,
          :now  => DateTime.now
      })
    }

    validates :clip, :length => {:minimum   => 3}
    validates :title, :length => {:minimum   => 1}

    # Setter to convert user's choice of 'A Week', etc. to an actual DateTime
    def lifespan=(lifespan)
      unless @@lifespans[lifespan].nil?
        self.expires = DateTime.now.advance(@@lifespans[lifespan])
      end
    end

    # Getter to convert an expire date to '1 Month', '1 Year', etc.
    def lifespan
      unless self.expires.nil?
        time_ago_in_words(self.expires)
      else
        "the end of time"
      end
    end

    # Utility method called by either cron job or when an expired clip is accessed
    def Clip.delete_expired_clips
      Clip.destroy_all(["expires is not null AND expires <= ?", DateTime.now])
    end

    private
      def default_values
        self.url_hash = Time.now.to_f.to_s.gsub('.','').to_i.to_s(36)
      end
  end
end
