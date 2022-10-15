require 'net/http'
require 'json'
require 'pathname'
require 'erb'
require 'optparse'
require 'fileutils'


def get_github(this, url)
  this["ci"] = nil

  puts "\n"
  path = Pathname.new("repo").expand_path
  if path.exist?
    path.rmtree
  end

  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  if not response.is_a?(Net::HTTPSuccess)
    puts "ERROR fetching #{url}"
    this["vcs_error"] = "ERROR"
    return
  end


  cmd = "git clone --depth 1 #{url} repo";
  puts cmd
  res = system(cmd)
  if not res
    this["vcs_error"] = "ERROR"
    return
  end


  wf = Pathname.new("repo/.github/workflows").expand_path
  if wf.exist?
    if Dir.glob("repo/.github/workflows/*.yml").length > 0 or Dir.glob("repo/.github/workflows/*.yaml").length > 0
      this["github_actions"] = 1
      this["ci"] = 1
    end
  end

  circle = Pathname.new("repo/.circleci").expand_path
  if circle.exist?
    if Dir.glob("repo/.circleci/*.yml").length > 0 or Dir.glob("repo/.circleci/*.yaml").length > 0
      this["circleci"] = 1
      this["ci"] = 1
    end
  end

  path = Pathname.new("repo").expand_path
  if path.exist?
    path.rmtree
  end
  return
end

def get_path(this, outdir)
  if this["gems"]["name"].length > 2
    dir = this["gems"]["name"][0..1]
    if /^[a-zA-Z0-9]{2}$/ !~ dir
      puts "ERROR Unhandled name #{dir}"
      return nil
    end
    # TODO: make directory name lower case???
    # TODO: verify the validity of the name? [a-zA-Z0-9_-] ?
  else
    dir = "_"
  end
  outpath = outdir + "/json/" + dir
  FileUtils.mkdir_p outpath
  outfile = outpath + "/" + this["gems"]["name"] + ".json"
  return outfile
end

def read_json(this, outdir)
  file_path = get_path(this, outdir)
  return if file_path.nil?
  return if not File.exists?(file_path)
  return JSON[File.read(file_path)]
end

def save_json(this, outdir)
  file_path = get_path(this, outdir)
  return if file_path.nil?

  puts "Saving '#{this["gems"]["name"]}'"
  File.write(file_path, this.to_json)
end

def collect_data(limit, outdir)
  url = "https://rubygems.org/api/v1/activity/just_updated"
  uri = URI(url)

  response = Net::HTTP.get_response(uri)
  if response.is_a?(Net::HTTPSuccess)
      raw_data = JSON[response.body]
  end

  seen = Hash.new
  latest_data = Array.new
  fetched_any = false
  updated_again = 0
  updated_new = 0

  raw_data.each do|entry|
    fetched_this = false
    if seen.key?(entry["name"])
      next
    end

    seen[entry["name"]] = 1

    this = { "gems" => entry }

    this["vcs_name"] = "Other"
    source_code_uri = this["gems"]["source_code_uri"]
    if source_code_uri.nil?
      if not this["gems"]["homepage_uri"].nil?
        if this["gems"]["homepage_uri"].start_with?('http://github.com/') or this["gems"]["homepage_uri"].start_with?('https://github.com/')
          source_code_uri = this["gems"]["homepage_uri"]
        end
      end
    end
    if not source_code_uri.nil?
      if source_code_uri.start_with?('http://github.com/') or source_code_uri.start_with?('https://github.com/')
        this["vcs_name"] = "GitHub"
        old = read_json(this, outdir)
        if old.nil? or old["gems"]["version"] != this["gems"]["version"]
          get_github(this, source_code_uri)
          fetched_this = true
          if old.nil?
            updated_new += 1
          else
            updated_again += 1
          end
        else
          next
        end
      end
    end

    next if not fetched_this

    fetched_any = true


    # TODO: entry["metadata"]["source_code_uri"]
    # TODO: entry["project_uri"]
    this["vcs_uri"] = source_code_uri
    latest_data.append(this)
    save_json(this, outdir)
    if limit.nil?
      next
    end

    limit -= 1
    puts limit
    if limit <= 0
      break
    end
  end

  print "raw_data: #{raw_data.length}\n" # 50 elements
  print "latest_data: #{latest_data.length}\n" # 50 elements

  #    puts entry["metadata"]["changelog_uri"]
  save_update(outdir, updated_new, updated_again)
  return fetched_any
end

def save_update(outdir, updated_new, updated_again)
  return if updated_new == 0 and updated_again == 0

  file_path = outdir + "/update.log"
  data = {
    date: Time.now,
    updated_new: updated_new,
    updated_again: updated_again,
  }
  File.open(file_path, mode="a") do|fh|
    fh.puts(data.to_json)
  end
end

def generate_table(latest_data)
  puts "Generate table"
  template = ERB.new(File.read('templates/list.erb'))
  content = template.result_with_hash(data: latest_data)
  return content
end

def generate_html(content, outdir)
  puts "Generate HTML"
  now = Time.now

  template = ERB.new(File.read('templates/main.erb'))
  html = template.result_with_hash(timestamp: now.utc.strftime("%Y-%m-%d %H:%M:%S"), content: content)

  File.write(outdir + '/index.html', html)
end

def read_all_json_files(outdir)
  puts "read all json files"
  json_files = Dir.glob(outdir + "/json/*/*.json")
  data = []
  json_files.each do|file|
    data.append(JSON[File.read(file)])
  end
  #print(data)

  return data
end

def main
  puts "Welcome to the Ruby Digger"
  limit = nil
  fetch = false
  generate = false
  outdir = 'docs'

  OptionParser.new do |opt|
    opt.on('--fetch') { |o| fetch = true }
    opt.on('--generate') { |o| generate = true }
    opt.on('--limit LIMIT') { |o| limit = o.to_i }
  end.parse!

  if not fetch and not generate
    puts "Usage #{$0} --fetch --generate [--limit N]"
    exit 1
  end

  if not Dir.exists? outdir
    Dir.mkdir outdir
  end

  fetched = nil
  if fetch
    puts "Fetch latest data"
    fetched = collect_data(limit, outdir)
  end

  if generate
    data = read_all_json_files(outdir)
    data.sort_by!{|item| item["gems"]["version_created_at"]}
    data.reverse!
    # TODO generate statistics
    if fetched.nil? or fetched
      table = generate_table(data)
      generate_html(table, outdir)
    end
  end
end

main
