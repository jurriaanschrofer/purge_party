# Purge Party

Delete all unused imports from your project's javascript files!

Simply
  1. download the repo
  2. open the `purge_party.rb` file
  3. pass your javascript project's `/src` directory to the 'run' method
  3. invoke the script (effectively calling `run`), through `ruby purge_party.rb`

Note
  1. currently displays all lines which may be deleted, but does not delete them yet
  2. as for now, requires ruby 3+ (but you can easily reverse engineer the file by substituting _1's & _2's with named arguments)
