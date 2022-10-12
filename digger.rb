require 'net/http'
require 'json'

puts "Welcome to the Ruby Digger"
url = "https://rubygems.org/api/v1/activity/just_updated"
uri = URI(url)
now = Time.now

response = Net::HTTP.get_response(uri)
if response.is_a?(Net::HTTPSuccess)
    raw_data = JSON[response.body]
end

seen = Hash.new
latest_data = Array.new

raw_data.each do|entry|
  if not seen.key?(entry["name"])
    seen[entry["name"]] = 1
    latest_data.append(entry)
  end
end

print "raw_data: #{raw_data.length}\n" # 50 elements
print "latest_data: #{latest_data.length}\n" # 50 elements

#    puts entry["metadata"]["changelog_uri"]
#    puts entry["metadata"]["source_code_uri"]
#    puts entry["project_uri"]
#    puts entry["source_code_uri"]

content = '
 <table class="table table-striped table-hover" id="sort_table">
      <thead>
        <tr>
          <th>Name</th>
          <th>Version</th>
          <th>Authors</th>
          <th>VCS</th>
          <th>Issues</th>
<!--
          <th>Date</th>
          <th>CI</th>
          <th>Licenses</th>
          <th>Dashboard</th>
-->
        </tr>
      </thead>
      <tbody>
'

latest_data.each do|entry|
  content += '<tr>'
  content += '<td><a href="' + entry["project_uri"] + '">' + entry["name"] + '</a></td>'
  content += '<td>' + entry["version"] + '</td>'
  content += '<td>' + entry["authors"] + '</td>'

  source_code_uri = entry["source_code_uri"]
  if source_code_uri.nil?
    if not entry["homepage_uri"].nil? and (entry["homepage_uri"].start_with?('http://github.com/') or entry["homepage_uri"].start_with?('https://github.com/'))
      source_code_uri = entry["homepage_uri"]
    end
  end

  if source_code_uri.nil?
    content +=  '<td><a class="badge badge-warning" href="/add-repo">Add repo</a></td>'
  else
    repo_type = 'Other'
    if source_code_uri.start_with?('http://github.com/') or source_code_uri.start_with?('https://github.com/')
      repo_type = 'GitHub'
    end
    content += '<td><a href="' + source_code_uri  + '">' + repo_type + '</a></td>'
  end

  bug_tracker_uri = entry["bug_tracker_uri"]
  if bug_tracker_uri.nil?
    content +=  '<td><a class="badge badge-warning" href="/add-repo">Add issues</a></td>'
  else
    content += '<td><a href="' + bug_tracker_uri  + '">issues</a></td>'
  end

  content += '</tr>'
  content += "\n"

end

content += '
     </tbody>
    </table>
'

outdir = 'docs'

if not Dir.exists? outdir
  Dir.mkdir outdir
end


html = '<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css" integrity="sha384-JcKb8q3iqJ61gNV9KGb8thSsNjpSL0n8PARn9HuZOnIxN0hoP+VmmDGMN5t9UJ0Z" crossorigin="anonymous">
    <!-- Optional theme -->
    <!-- link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap-theme.min.css" -->
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css">
    <link rel="stylesheet" href="//cdn.datatables.net/1.10.22/css/jquery.dataTables.min.css">
    <!-- Custom styles for this template -->
    <link rel="stylesheet" href="/css/style.css">
    <title>Ruby Digger</title>
  </head>
  <body>
    <!-- Fixed navbar -->
    <nav class="navbar navbar-expand-md navbar-dark bg-dark fixed-top">
      <a class="navbar-brand" href="/">Ruby Digger</a>
      <div class="navbar-collapse collapse">
        <ul class="navbar-nav mr-auto">
           <li class="nav-item"><a class="nav-link" href="https://cpan-digger.perlmaven.com/">CPAN Digger</a></li>
           <li class="nav-item"><a class="nav-link" href="https://pydigger.com/">PyDigger</a></li>
<!-- <li class="nav-item"><a class="nav-link" href="/stats.html">Stats</a></li> -->
         </ul>
      </div>
    </nav>

    <div class="container" role="main">
    <h1>Ruby Digger</h1>
    <div>
    Showing the most recent uploads to RubyGems.
    <ul>
      <li>Having the link to your public Version Control System (VCS) help others to contribute to your code.</li>
      <li>Having an explicit link to your bugtracker/issues helps people know where to submit bug reports.</li>
      <li>Having Continuous Integration (CI) configured helps the author catch regression and platform incompability much faster.</li>
      <li>Having license information can help people automatically verify that they use only approved licenses.</li>
      <!-- <li><span class="badge badge-danger">No</span> means the author does not have public VCS and does not want to have one.</li> -->
    </ul>
    </div>


'

html +=  content

html += '
    </div>
    <footer>
Ruby Digger written by <a href="https://twitter.com/szabgab">@szabgab</a> / Code on <a href="https://github.com/szabgab/ruby-digger">Github</a> / Last updated: ' + now.utc.strftime("%Y-%m-%d %H:%M:%S") + ' /
Support the work via <a href="https://www.patreon.com/szabgab">Patreon</a> or <a href="https://github.com/sponsors/szabgab">GitHub</a>.
    </footer>
    <!-- jQuery (necessary for Bootstrap\'s JavaScript plugins) -->
    <script src="https://code.jquery.com/jquery-3.5.1.min.js"></script>
    <!-- Latest compiled and minified JavaScript -->
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/js/bootstrap.min.js" integrity="sha384-B4gt1jrGC7Jh4AgTPSdUtOBvfO8shuf57BaghqFfPlYxofvL8/KUEfYiJOMMV+rV" crossorigin="anonymous"></script>
    <script src="//cdn.datatables.net/1.10.22/js/jquery.dataTables.min.js"></script>
    <script src="/js/digger.js"></script>

  </body>
</html>
'

File.write(outdir + '/index.html', html)

