require 'pathname'
require 'fileutils'
require 'date'
require 'yaml'
require 'csv'

module Protein
  # Functional goodness
  def zipmap(coll, &f)
    Hash[*coll.zip(coll.map f).flatten]
  end

  def identity(x)
    x
  end

  # Lightweight data file queries
  def delims
    { 
      tsv: "\t",
      csv: ","
    }
  end
  
  def cell(file, r, c, delim="\t")
    File.read(file).
      split("\n")[r].chomp.
      split(delim)[c]
  end

  # Returns the nth column (or range of columns) in file, skipping
  # skip rows
  def col(file, n, skip=0, delim="\t")
    File.read(file).
      split("\n")[skip..-1].
      map {|l| l.chomp.split(delim)[n] }
  end

  # Returns the probable header row from a data file, along
  # with its index.
  def find_header_row(file, delim="\t")
    # Read and compact all rows
    rows = File.read(file).split("\n").
             map {|l| l.chomp.split(delim).compact }
  
    # Look for the first row with the least nil values,
    # and return its index
    i = rows.index rows.max_by(&:length)
    return rows[i], i
  end

  # Returns the data from column name, where name is found in the probable
  # header row in file
  def named_column(file, name, delim="\t")
    headers, i = find_header_row(file, delim)
    column = headers.index name
    col(file, column, i, delim)
  end

  # General helpers
  def date_from(month, day, year)
    year = '20' + year if year.length == 2
    Date.parse "#{year}-#{month}-#{day}"
  end

  def normalize_path(dir1, dir2)
    path1 = dir1.respond_to?(:expand_path) ? dir1 : Pathname.new(dir1).expand_path
    path2 = dir2.respond_to?(:expand_path) ? dir2 : Pathname.new(dir2).expand_path
    path1.relative_path_from path2
  end

  def ensure_directory(dir)
    FileUtils.mkdir_p dir
  end

  def update_yaml(new_opts, file)
    curr_opts = file.exist? ? YAML.load_file(file) : {}

    File.open file, 'w' do |f|
      YAML.dump curr_opts.merge(new_opts), f
    end
  end
end
