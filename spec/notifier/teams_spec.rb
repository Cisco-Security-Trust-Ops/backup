require "spec_helper"

module Backup
  describe Notifier::Teams do
    let(:model) { Model.new(:test_trigger, "test label") }
    let(:notifier) { Notifier::Teams.new(model) }

    it_behaves_like "a class that includes Config::Helpers"
    it_behaves_like "a subclass of Notifier::Base"

    describe "#initialize" do
      it "provides default values" do
        expect(notifier.roomId).to be_nil
        expect(notifier.token).to be_nil

        expect(notifier.on_success).to be(true)
        expect(notifier.on_warning).to be(true)
        expect(notifier.on_failure).to be(true)
        expect(notifier.max_retries).to be(10)
        expect(notifier.retry_waitsec).to be(30)
      end

      it "configures the notifier" do
        notifier = Notifier::Teams.new(model) do |teams|
          teams.roomId      = "my_roomId"
          teams.token       = "my_token"

          teams.on_success     = false
          teams.on_warning     = false
          teams.on_failure     = false
          teams.max_retries    = 5
          teams.retry_waitsec  = 10
        end

        expect(notifier.roomId).to eq "my_roomId"
        expect(notifier.token).to eq "my_token"

        expect(notifier.on_success).to be(false)
        expect(notifier.on_warning).to be(false)
        expect(notifier.on_failure).to be(false)
        expect(notifier.max_retries).to be(5)
        expect(notifier.retry_waitsec).to be(10)
      end
    end # describe '#initialize'
    describe "#notify!" do
      let(:expected_titles) do
        ["Job", "Started", "Finished", "Duration", "Version"]
      end

      let(:expected_titles_with_log) do
        expected_titles + ["Detailed Backup Log"]
      end

      let(:uri) do
        "https://api.ciscospark.com:443/v1/messages"
      end

      let(:notifier) do
        Notifier::Teams.new(model) do |teams|
          teams.roomId = "my_backup_status_room"
          teams.token  = "32423445u98ujrjfiudshfaksjdbfiasuldf"
        end
      end

      def expected_net_http_params(request, status, send_log = false)
        expect(request.uri.to_s).to eq(uri)
        expect(request.headers["Content-Type"]).to include("multipart/form-data")
        expect(request.headers["Authorization"]).to eq("Bearer #{notifier.token}")
        expect(request.body).to match(/Content-Disposition: form-data; name="roomId"[^0-9a-zA-Z]+#{notifier.roomId}/)
        # Regex here was so long that it exceed rubocop rather generous specs
        # The (?x) turns ignores white space and allows multi-line but for spaces have to use \s
        expect(request.body).to match(/(?x)Content-Disposition:\sform-data;\sname="text"[^0-9a-zA-Z]+
                                      \[Backup::#{status.to_s.capitalize}\]\stest\slabel\s\(test_trigger\)/)
        expect(request.body).to match(/Content-Disposition: form-data; name="files"; filename="log"/)
        if send_log
          expect(request.body).to match(/---BEGIN LOG---/)
          expect(request.body).to match(/---END LOG---/)
        else
          expect(request.body).to_not match(/---BEGIN LOG---/)
        end
        { status: 200 }
      end

      context "when status is :success" do
        it "sends a success message" do
          stub_request(:any, "https://api.ciscospark.com/v1/messages")
            .to_return do |request|
              expected_net_http_params(request, :success)
            end
          notifier.send(:notify!, :success)
        end
      end

      context "when status is :warning" do
        it "sends a warning message" do
          stub_request(:any, "https://api.ciscospark.com/v1/messages")
            .to_return do |request|
              expected_net_http_params(request, :warning, true)
            end
          notifier.send(:notify!, :warning)
        end
      end

      context "when status is :failure" do
        it "sends a failure message" do
          stub_request(:any, "https://api.ciscospark.com/v1/messages")
            .to_return do |request|
              expected_net_http_params(request, :failure, true)
            end
          notifier.send(:notify!, :failure)
        end
      end
    end # describe '#notify!'
  end
end
