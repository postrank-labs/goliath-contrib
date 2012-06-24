require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "SonOfABatch" do

  describe "timeout param" do
    it "accepts a timeout param"
    it "coerces the timeout param within range"
  end

  describe "request format" do
    it "requires well-formed URLs (BadRequestError)"
    it "requires one or more URLs (BadRequestError)"
    it "accepts at most 100 URLs at a time (BadRequestError)"

    it "raises ForbiddenError if URL is not whitelisted"
  end

  describe "proxy" do
    it "sends requests to multiple downstream hosts"
  end

  context "JSON response" do
    it "returns a well-formed hash" do
      # parsed_response = {}
      # parsed_response['results'].should be_a_kind_of(Hash)
      # parsed_response['errors'].should be_a_kind_of(Hash)
    end

    it "ends each result line except the last with a comma"
    it "sends the stats back in a single line"
    it "sends the errors back in a single line"
    it "escapes the target response"
    it "sends back the errors last" do
    end

    it "considers a successful non-200 from the client to be a result, not an error"
  end

  context 'TSV response' do
    it "sends [event_type, request_id, status, body], tab-separated"
    it "serializes out errors and results in order received"
    it "removes newlines or linefeeds in the response"
    it "does not mess with tabs in the response"
    it "sends a stats line at the end"
    it "considers a successful non-200 from the client to be a result, not an error"
  end
end
