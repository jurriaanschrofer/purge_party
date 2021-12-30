# Script settings, adjust to your preferences.

DebugMode               = false
DebugHaltExecution      = false
IncludeNonDeletables    = false

# Only require pry if necessary, so that all folks without pry may still
# use this beautiful script ;).
require "pry" if DebugMode

# Regular expression, tweak as desired. Alternatives are commented.

FilePaths               = /.*.js$/
FileImports             = /import.*$/              # /import[ {}a-zA-Z'"\t\/_,-.0-9@]{1,}$/
FileImportCriterium     = /(?<=import).*(?=from)/
ImportConstantsBlock    = /(?<=import ).*(?=from)/ # /(?<=import )[a-zA-Z0-9 ,{}_*]{1,}(?=from)/
ImportCOnstantsSplitter = /[{},]/

# The runner methods merely exist as the skeleton that invokes all helper
# methods which do the actual work.

def run
  index = files_index.map { process_file(_1) }
  index.select! { _1[:imports].any? } if !IncludeNonDeletables
  puts index
end

def process_file(file_path)
  contents        = file_contents_without_imports(file_path)
  imports         = file_imports_index(file_path)
  import_trackers = imports.map { process_import(*_1, contents) }.inject(&:merge) || {}

  import_trackers.select! { _2[:deletable] } unless IncludeNonDeletables
  { file: file_path, imports: import_trackers }
end

def process_import(line_no, import_line, file_contents)
  block       = import_constants_block(import_line)
  constants   = import_constants(block)
  invocations = constants.map { constant_occurences(_1, file_contents) }.inject(&:merge) || {}
  deletable   = invocations.values.any? && invocations.values.all?(0)
  analysis    = { line_no => { deletable: deletable, invocations: invocations } }
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
