# Script settings, adjust to your preferences.

DebugMode               = false
DebugHaltExecution      = false

# Only require pry if necessary, so that all folks without pry may still
# use this beautiful script ;).
require "pry" #if DebugMode

# Regular expression, tweak as desired. Alternatives are commented.

FilePaths               = /.*.js$/
FileImports             = /(?<![a-zA-Z ]{3})import.*$/ # /import[ {}a-zA-Z'"\t\/_,-.0-9@]{1,}$/
FileImportCriterium     = /(?<=import).*(?=from)/
ImportConstantsBlock    = /(?<=import).*(?=from)/      # /(?<=import )[a-zA-Z0-9 ,{}_*]{1,}(?=from)/
ImportCOnstantsSplitter = /[{},]|[a-zA-Z]{1,} as/
FileImportExclusion     = /\* {1,}as {1,}/

# The runner methods merely exist as the skeleton that invokes all helper
# methods which do the actual work.

def run
  index = files_index.map { process_file(_1) }
  return unless proceed_to_delete?(count_deletables(index))
  delete_lines_from_files(index)
end

def process_file(file_path)
  contents          = file_contents_without_imports(file_path)
  imports           = file_imports_index(file_path)
  import_trackers   = imports.map { process_import(*_1, contents) }.inject(&:merge) || {}
  file_lines_index  = file_lines_index(file_path)
  file_info         = { file: file_path, imports: import_trackers, file_lines_index: file_lines_index }
  new_file_contents = parse_new_file_contents(file_info)

  file_info.merge!(new_file_contents)
end

def process_import(line_no, import_line, file_contents)
  block         = import_constants_block(import_line)
  constants     = import_constants(block)
  skip_deletion = !!(block =~ FileImportExclusion)
  invocations   = constants.map { constant_occurences(_1, file_contents) }.inject(&:merge) || {}
  deletable     = skip_deletion ? false : (invocations.values.any? && invocations.values.all?(0))

  { line_no => { deletable: deletable, invocations: invocations } }
end

def constant_occurences(constant, file_contents)
  regex      = Regexp.new("(?<![a-zA-Z])#{constant}(?![a-zA-Z])")
  occurences = file_contents.scan(regex).count
  { constant => occurences }
end

# Below methods are the helper methods which actually perform most of the logic.

def files_index(files_root="/Users/jurriaanschrofer/Documents/eitje_web/src")
  paths = Dir["#{files_root}/**/**"]
  paths.select! { _1 =~ FilePaths }
end

def file_contents(file_path)
  File.open(file_path).read
end

def file_contents_without_imports(file_path)
  file_contents(file_path).split("\n").reject { _1 =~ FileImports }.join("\n")
end

def file_lines_index(file_path)
  lines = file_contents(file_path).split("\n")
  index = lines.map.with_index(1) { |*x| x.reverse }.to_h
end

def file_imports_index(file_path)
  imports = file_lines_index(file_path).select do
    _2 =~ FileImports && _2 =~ FileImportCriterium
  end
  debug(__method__, imports, file_path)
  imports
end

def import_constants_block(import_line)
  import_constants_block = import_line.slice(ImportConstantsBlock)
  debug(__method__, import_line, import_constants_block)
  import_constants_block || ''
end

def import_constants(constants_block)
  constants = constants_block.split(ImportCOnstantsSplitter)
  constants = constants.map { _1.strip }.select { !_1.empty? }
  debug(__method__, constants_block, constants)
  constants
end

def parse_new_file_contents(file_info)
  deletable_linenos    = select_delatables(file_info)
  file_changes_present = deletable_linenos.any?
  filtered_index       = file_info[:file_lines_index].select { !deletable_linenos.include?(_1) }
  parsed_contents      = filtered_index.values.join("\n")

  { file_changes_present: file_changes_present, new_file_contents: parsed_contents}
end

def select_delatables(file_info)
  deletables_index = file_info[:imports].select { _2[:deletable] }
  print_deletables(file_info, deletables_index)
  deletable_linenos = deletables_index.keys
end

def print_deletables(file_info, deletables_index)
  return unless deletables_index.any?
  file_name       = file_info[:file]
  formatted_lines = deletables_index.map { "#{_1[0].to_s.ljust(5)}#{file_info.dig(:file_lines_index, _1[0])}" }
  parsed_lines    = formatted_lines.join("\n")
  puts <<~EOL

  To be deleted from file: #{file_name}
  #{parsed_lines}

  EOL
end

def proceed_to_delete?(deletables_count)
  puts "Do you want to proceed deleting above stated #{deletables_count} lines? (y/n)"
  answer  = gets
  proceed = answer.strip == "y"
  if proceed
    puts "proceeding to delete unused import lines form your project..."
  else
    puts "aborting operation..."
  end
  proceed
end

def delete_lines_from_files(index)
  index.each do |file_info|
    next unless file_info[:file_changes_present]
    File.open(file_info[:file], "w+") do |f|
     f << file_info[:new_file_contents]
   end
  end
end

def count_deletables(index)
  count_per_file = index.map do |file_info|
    next unless file_info[:file_changes_present]
    file_info[:imports].count { _2[:deletable] }
  end
  count_per_file.compact.sum
end

# Debuggers are separated from the code, in order to allow the core code
# to be easily read and the debuggers to be kept. Debugger method names
# correspond to heir respective methods name.

def debug(_method, *args)
  return unless DebugMode
  send("debug_#{_method}", *args)
  rescue => e
    print_header(_method) && send("print_#{_method}", *args)
    binding.pry if DebugHaltExecution
end

def print_header(_method)
    puts <<~EOL

    ---
    debugging '#{_method}'
    EOL
    true
end

def print_file_imports_index(imports, file_path)
  puts <<~EOL
    imports   : #{imports}
    file_path : #{file_path}
  EOL
end

def debug_file_imports_index(imports, file_path)
  raise ArgumentError if imports.empty?
end

def print_import_constants_block(import_line, constants_block)
  puts <<~EOL
    constants_block: #{constants_block}
    line           : #{import_line}
  EOL
end

def debug_import_constants_block(import_line, constants_block)
  raise ArgumentError if constants_block.empty?
end

def print_import_constants(constants_block, constants)
  puts <<~EOL
    constants      : #{constants}
    constants_block: #{constants_block}
  EOL
end

def debug_import_constants(constants_block, constants)
  raise ArgumentError if constants.empty?
end

# Invocation

run
