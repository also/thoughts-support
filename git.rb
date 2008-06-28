HEAD = 'HEAD'

class Git
  def initialize(repository)
    @repository = repository
  end
  
  def current_commit
    puts "Retrieving current commit"
    show_ref(:s,  HEAD).chomp
  end
  
  def commits_for_file(file_name)
    puts "Retrieving commits on #{file_name}"
    rev_list(HEAD, file_name).split
  end
  
  def commits_since(since)
    puts "Retrieving commits since #{since}"
    rev_list("--since=\"#{since}\"", HEAD).split
  end
  
  def files_changed_in(commit = HEAD)
    puts "Retrieving files changed in #{commit}"
    changes = diff_tree(:r, :name_status, :root, commit).split "\n"
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
  
  def files_changed_since(commit)
    puts "Retrieving files changed since #{commit}"
    diff_tree(:r, :name_only, :root, commit, HEAD).split
  end
  
  def method_missing(name, *args)
    Dir.chdir @repository do
      args = args.map do |arg|
        if arg.instance_of? Symbol
          string = arg.to_s.gsub('_', '-')
          if string.length == 1
            '-' + string
          else
            '--' + string
          end
        else
          arg
        end
      end
    
      name = name.to_s
    
      name = name[4..-1] if name[0..3] == 'git_'
    
      command = "git-#{name.gsub('_', '-')}"
      command += " #{args.join(' ')}" if args.length > 0
      puts "* exec \"#{command}\""
      result = `#{command} 2>&1`
      
      raise "Git command failed: #{result}" if $? != 0
      
      result
    end
  end
end