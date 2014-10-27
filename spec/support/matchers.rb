RSpec::Matchers.define :be_incremented_for do |expected|
  match do |actual|
    actual.values[expected] > 0
  end

  failure_message_for_should do |actual|
    "expected '#{ expected }' to be incremented, but it wasn't"
  end
end
