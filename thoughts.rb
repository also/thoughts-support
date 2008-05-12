require 'rubygems'
require 'redcloth'
require 'erb'

RedCloth::DEFAULT_RULES.replace [:markdown, :textile]

HEAD = 'HEAD'

class Git
  def self.get_current_commit
    Git.show_ref('-s',  HEAD).chomp
  end
  
  def self.commits_for_file(file_name)
    Git.rev_list(HEAD, file_name).split
  end
  
  def self.commits_for_period(period)
    Git.rev_list("--since=\"#{period} ago\"", HEAD).split
  end
  
  def self.method_missing(name, *args)
    command = "git-#{name.to_s.gsub('_', '-')} #{args.join(' ')}"
    puts "*exec \"#{command}\""
    `#{command}`
  end
  
  def self.files_changed(commit = HEAD)
    changes = Git.diff_tree('-r', '--name-status', '--root', commit).split "\n"
    changes.shift
    added = []
    changed = []
    changes.each do |line|
      change = line.split
      if change[0] == 'A'
        added << change[1]
      else
        changed << change[1]
      end
    end
    
    {:added => added, :changed => changed}
  end
end

class Thought
  def initialize(file_name, template)
    @file_name = file_name
    @template = template
  end
  
  def update
    write_cached_html
  end
  
  def uri
    @file_name[0..-6]
  end
  
  def html
    unless @html
      generate_html
    end
    @html
  end
  
  def title
    m = html.match '<h1>(.+)</h1>'
    if m
      m[1]
    else
      nil
    end
  end
  
  def generate_html
    @html = RedCloth.new(IO.read(@file_name)).to_html()
  end
  
  def write_cached_html
    FileUtils.mkdir_p File.dirname(".thoughts/cache/#{@file_name}.html")
    file = File.new(".thoughts/cache/#{@file_name}.html", 'w')
    file.puts @template.result(binding)
  end
  
  def self.is_thought_file(file)
    file[-5..-1] == '.text'
  end
end

class Site
  def initialize
    @individual_template = ERB.new(IO.read('.thoughts/thought.erb'))
    @index_template = ERB.new(IO.read('.thoughts/index.erb'))
  end
  
  def update(previous_commit)
    thoughts = []
    changed_files = Git.diff_tree('-r', '--name-only', '--root', previous_commit, HEAD).split
    changed_files.each do |file|
      if Thought.is_thought_file file
        thought = Thought.new(file, @individual_template)
        thought.update
        thoughts << thought
        puts "Updated thought #{file}"
      end
    end
    
    write_index
  end
  
  def write_index
    puts 'Updating index'
    commits = Git.commits_for_period '1 month'
    thoughts = []
    commits.each do |commit|
      files = Git.files_changed(commit)[:added]
      files.each do |file|
        if Thought.is_thought_file file
          thoughts << Thought.new(file, @individual_template)
          puts "Added #{file} to index"
        end
      end
    end
    
    file = File.new(".thoughts/cache/index.html", 'w')
    file.puts @index_template.result(binding)
      
  end
    
end

Dir.chdir(ARGV[0])
ENV['GIT_WORK_TREE'] = ARGV[0]
ENV['GIT_DIR'] = ARGV[0] + '/.git'
previous_commit = Git.get_current_commit
Git.pull

case ARGV[1]
when 'update'
  puts 'Updating Thoughts'
  Site.new.update previous_commit
  puts 'Done'
else
  STDERR.puts "Invalid command #{ARGV[1]}"
end
