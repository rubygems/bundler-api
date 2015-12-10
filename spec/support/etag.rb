RSpec.shared_examples "return 304 on second hit" do
  describe "on second hit" do
    it "returns 304" do
      get url
      etag = last_response.header["ETag"]

      get url, {}, "HTTP_IF_NONE_MATCH" => etag
      expect(last_response.status).to eq(304)
    end
  end
end
