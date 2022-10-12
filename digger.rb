require 'net/http'
require 'json'

puts "Welcome to the Ruby Digger"
host = "rubygems.org"
path = "/api/v1/activity/just_updated"
uri = URI('https://' + host + path)

response = Net::HTTP.get_response(uri)
if response.is_a?(Net::HTTPSuccess)
    data = JSON[response.body]
end

# puts data.length # 50 elements
data.each do|entry|
    puts entry["name"]
    puts entry["version"]
    puts entry["authors"]
    puts entry["metadata"]["homepage_uri"]
    puts entry["metadata"]["changelog_uri"]
    puts entry["metadata"]["source_code_uri"]
    puts entry["project_uri"]
    puts entry["homepage_uri"]
    puts entry["source_code_uri"]
    puts entry["bug_tracker_uri"]
end
