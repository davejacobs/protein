require 'date'

module Protein
  # Returns the following groups based on `file`'s filename
  #   $1 - Print date, in the form 082010 (2010-08-20)
  #   $2 - Slide number (two or three digits)
  #   $3 - Gain minimum
  #   $4 - Gain maximum
  def self.parse_scan_file_name(file)
    /(\d{2})(\d{2})(\d{2})[-_](\d{2,3})[\s_]?\(?(\d{2})[-_](\d{2})\)?/.match(file.to_s)
    gain_min, gain_max = $5.to_i, $6.to_i

    [ date_from($1, $2, $3), $4, gain_min..gain_max ]
  end

  # Returns the scan date based on directory_name (or nil if not parseable),
  # along with any remaining descriptive text in the directory name
  def self.parse_scan_folder_name(directory_name)
    # Old expression, which doesn't match dates of the form MMDDYY:
    # /(\d{1,2}).(\d{1,2}).(\d{1,2}).*/.match(directory_name.to_s)

    /(\d{1,2})[^\d](\d{1,2})[^\d](\d{2})(.*)|(\d{2})(\d{2})(\d{2})(.*)/.match(directory_name.to_s)

    if $1 and $2 and $3
      [ date_from($1, $2, $3), $4 ] # $4 will return a description if present
    elsif $5 and $6 and $7
      [ date_from($5, $6, $7), $8 ] # $8 will return a description if present
    else
      [ Date.today, nil ] # use today as a default scan date
    end
  end

  # Returns an ordered list of gene names from the platemap described
  # in file
  def self.map_plate(file)
    return nil unless file and File.exist?(file)

    platemap = named_column(file, 'Gene ID', 2) || 
      named_column(file, 'GeneID', 5)
    platemap.map {|g| g.gsub(/\"|^\s*/, '') } #.gsub(/^\s*/, '')
  end

  # Parses NAPPA patient -> slide log, returning an array of the following
  # format: [ '104', 'PIC44', '1' ]
  def self.map_log(file, delim="\t")
    skip = 1
    n = 0
    
    [ col(file, n, skip, delim),
      col(file, n+1, skip, delim).map {|p| p && p.gsub(/\"/, '') },
      col(file, n+2, skip, delim) ]
  end
end
