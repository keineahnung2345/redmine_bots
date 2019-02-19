module RedmineBots::Telegram
  class Bot
    class MessageSender
      SLEEP_TIME = 30
      FARADAY_SLEEP_TIME = 5

      class BotKickedError
        def self.===(e)
          e.is_a?(Telegram::Bot::Exceptions::ResponseError) && e.message.include?('kicked')
        end
      end

      class FloodError
        def self.===(e)
          e.is_a?(Telegram::Bot::Exceptions::ResponseError) && e.message.include?('Too Many Requests')
        end
      end

      class UserDeactivatedError
        def self.===(e)
          e.is_a?(Telegram::Bot::Exceptions::ResponseError) && e.message.include?('user is deactivated')
        end
      end

      class SocksConnectionError
        def self.===(e)
          e.is_a?(Faraday::ConnectionFailed) && e.message.include?("Can't complete SOCKS5 connection to")
        end
      end

      def self.call(params)
        new(params).call
      end

      attr_reader :chat_id, :message, :bot_token, :params

      def initialize(params)
        @message = params.fetch(:message)
        @chat_id = params.fetch(:chat_id)
        @bot_token = params.fetch(:bot_token)
        @params = params.except(:message, :chat_id, :bot_token)
      end

      def call
        tries ||= 3
        socks_tries ||= 50
        message_params = {
          chat_id: chat_id,
          text: message,
          parse_mode: 'HTML',
          disable_web_page_preview: true,
        }.merge(params)

        bot.api.send_message(message_params)
      rescue BotKickedError
        logger.warn("Bot was kicked from chat. Chat Id: #{chat_id}, params: #{params.inspect}")
      rescue UserDeactivatedError
        logger.warn("User is deactivated: #{chat_id}, params: #{params.inspect}")
      rescue FloodError => e
        logger.warn("Too many requests. Sleeping #{SLEEP_TIME} seconds...")
        sleep SLEEP_TIME
        (tries -= 1).zero? ? raise(e) : retry
      rescue SocksConnectionError => e
        (socks_tries -= 1).zero? ? raise(e) : retry
      rescue Faraday::ClientError => e
        logger.warn("Faraday client error. Sleeping #{FARADAY_SLEEP_TIME} seconds...")
        sleep FARADAY_SLEEP_TIME
        (tries -= 1).zero? ? raise(e) : retry
      end

      private

      def bot
        @bot ||= ::Telegram::Bot::Client.new(bot_token)
      end

      def logger
        @logger ||= Logger.new(Rails.root.join('log/redmine_bots',
                                           'message-sender.log'))
      end
    end
  end
end
