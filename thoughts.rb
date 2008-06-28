$: << File.dirname(__FILE__)
require 'rubygems'
require 'redcloth'
require 'erb'
require 'git'

RedCloth::DEFAULT_RULES.replace [:markdown, :textile]

class Entry
  attr_reader :status
  
  def initialize(file_name, site)
    @file_name = file_name
    
    @site = site
    @status = :published
  end
  
  def hidden?
    @status == :hidden
  end
  
  def draft?
    @status == :draft
  end
  
  def update
    write_cached_html
  end
  
  def uri
    slug
  end
  
  def slug
    @slug ||= @file_name[0..-6]
  end
  
  def html
    @html ||= RedCloth.new(markdown).to_html
  end
  
  def title
    markdown # parse the irb
    @title ||= begin
      m = html.match '<h1>(.+)</h1>'
      if m
        m[1]
      else
        nil
      end
    end
  end
  
  def erb
    @erb ||= ERB.new(IO.read("#{@site.repository_path}/#{@file_name}"))
  end
  
  def markdown
    @markdown ||= erb.result binding
  end
  
  def write_cached_html
    html_file_name = "#{@repository_path}/.thoughts/cache/#{slug}.html"
    FileUtils.mkdir_p File.dirname(html_file_name)
    file = File.new(html_file_name, 'w')
    file.puts @site.individual_template.result(binding)
  end
  
  def self.is_entry_file(file)
    file[-5..-1] == '.text'
  end
end

class Site
  attr_reader :repository_path
  
  def initialize(repository_path)
    @repository_path = repository_path
    @repository = Git.new(repository_path)
  end
  
  def individual_template
    @individual_template ||= ERB.new(IO.read("#{@repository_path}/.thoughts/entry.erb"))
  end
  
  def index_template
    @index_template ||= ERB.new(IO.read("#{@repository_path}/.thoughts/index.erb"))
  end
  
  def update
    previous_commit = @repository.current_commit
    @repository.pull
    
    entries = []
    changed_files = @repository.files_changed_since previous_commit
    changed_files.each do |file|
      if Entry.is_entry_file file
        entry = Entry.new(file, self)
        entry.update
        entries << entry
        puts "Updated entry #{file}"
      end
    end
    
    write_index
  end
  
  def write_index
    puts 'Updating index'
    commits = @repository.commits_since '1 month ago'
    entries = []
    commits.each do |commit|
      files = @repository.files_changed_in(commit)[:added]
      files.each do |file|
        if Entry.is_entry_file file
          entry = Entry.new(file, self)
          entries << entry
          puts "Added \"#{entry.title}\" (#{file}) to index"
        end
      end
    end
    
    file = File.new("#{@repository_path}.thoughts/cache/index.html", 'w')
    file.puts index_template.result(binding)
      
  end
end

case ARGV[1]
when 'update'
  puts 'Updating Entries'
  Site.new(ARGV[0]).update
  puts 'Done'
else
  $stderr.puts "Invalid command #{ARGV[1]}"
end
