require "uri"
require "json"
require "tempfile"
require "net/http/post/multipart"

module Backup
  module Notifier
    class Teams < Base
      ##
      # The user or bot token
      attr_accessor :token

      ##
      # The roomId to send messages to
      attr_accessor :roomId

      ##
      # Array of statuses for which the log file should be attached.
      #
      # Available statuses are: `:success`, `:warning` and `:failure`.
      # Default: [:warning, :failure]
      attr_accessor :send_log_on

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?

        @send_log_on ||= [:warning, :failure]
      end

      private

      ##
      # Notify the user of the backup operation results.
      #
      # `status` indicates one of the following:
      #
      # `:success`
      # : The backup completed successfully.
      # : Notification will be sent if `on_success` is `true`.
      #
      # `:warning`
      # : The backup completed successfully, but warnings were logged.
      # : Notification will be sent if `on_warning` or `on_success` is `true`.
      #
      # `:failure`
      # : The backup operation failed.
      # : Notification will be sent if `on_warning` or `on_success` is `true`.
      #
      def notify!(status)
        temp_file = Tempfile.new("teams_attachment")
        temp_file.write(attachment(status))
        temp_file.close

        model_params = {}
        model_params[:roomId] = roomId
        model_params[:text] = message.call(model, status: status_data_for(status))
        model_params[:files] = UploadIO.new(temp_file.path, "text/plain", "log")

        url = URI.parse("https://api.ciscospark.com/v1/messages")
        net = Net::HTTP.new(url.host, url.port)
        net.use_ssl = true
        res = net.start do |http|
          req = Net::HTTP::Post::Multipart.new(url, model_params)
          req.add_field("Authorization", "Bearer #{token}") # add to Headers
          http.request(req)
        end
        temp_file.unlink
        raise "Invalid server response #{res.code}: #{res.message}" unless res.is_a? Net::HTTPSuccess
      end

      #
      # Creates an attachment message.
      #
      def attachment(status)
        msg = ""
        msg += "Job: #{model.label} (#{model.trigger})\n"
        msg += "Started:  #{model.started_at}\n"
        msg += "Finished: #{model.finished_at}\n"
        msg += "Duration: #{model.duration}\n"
        if send_log_on.include?(status)
          msg += "\n\n"
          msg += "---BEGIN LOG---"
          msg += Logger.messages.map(&:formatted_lines).flatten.join("\n")
          msg += "---END LOG---"
        end
        msg
      end
    end
  end
end
