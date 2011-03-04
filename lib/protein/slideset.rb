require 'csv'
require 'fileutils'
require 'pathname'

require 'protein/helpers'
require 'protein/patient_sample'
require 'protein/slide'

module Protein
  # The SlideSet class describes one "printing" of NAPPA slides. It
  # includes a series of slides that all have the same platemap (gene-
  # to-plate-position map) but which have been probed with different
  # patient sera or plasma.
  #
  # A SlideSet is derived from a directory with a particular structure:
  #
  #   1. Log.tsv - A patient sample log, corresponding slide numbers 
  #      with serum/plasma specifics.
  #   
  #   2. Platemap.tsv - A mapping of gene names to positions on each
  #      slide in this slide set.
  #   
  #   3. A subdirectory for each NAPPA scan date, where the directory
  #      name corresponds to that date:
  #
  #      mm_dd_yy
  #
  #   4. In each subdirectory, there should be a .tiff file, a .jpg file,
  #      and a .txt or .tsv file, all named in the following way:
  #
  #      mmddyy-SSS (min-max).tsv
  #
  #         - OR -
  #      
  #      mmddyy_SSS_min_max.tsv
  #
  #      mm - Month
  #      dd - Day
  #      yy - Year
  #      SSS - Slide number
  #      min - Minimum gain
  #      max - Maximum gain
  #
  #  Given this structure, the SlideSet class will represent and aggregate
  #  all of this data as a single object structure that can then be
  #  easily manipulated.
  class SlideSet
    # The directory and name should be set only once
    attr_reader :directory, :name

    # The platemap, patient log, and slide collection are not
    # immutable because you may want to load them in after initializing
    # the SlideSet (to separate different operations from each other
    # and not, say, re-parse the platemap when all you want is a refreshed
    # set of images).
    attr_accessor :platemap, :patient_log, :slides

    # The key files in your directory should match the following names
    def self.defaults
      {
        :platemap_file => 'Platemap.tsv',
        :log_file => 'Log.csv',
        :summary_file => 'Summary.csv',
        :thumbs_directory => 'Thumbs'
      }
    end

    # Creates a SlideSet from a directory, guessing the set's name
    # from the directory if a name is not provided. Note: instantiating
    # a SlideSet does not parse any files by default. To parse all
    # files and create all summaries on SlideSet creation, set process_all
    # to true.
    def initialize(directory, process_on_creation=false)
      # I don't use accessor methods to set these variables...
      # because there are none
      @directory = Pathname.new(directory).expand_path
      @name = guess_name_from(directory)

      # These will be initiated in later methods
      self.platemap = []
      self.patient_log = {}
      self.slides = []
      
      # All further references to the working directory (from this
      # class) should refer to the root directory.
      Dir.chdir(directory)

      return nil unless validate_structure
      process_data if process_on_creation
    end

    # This method guesses a name for your slideset based on your
    # root directory
    def guess_name_from(directory)
      directory.to_s.
        split(/\W+/).
        map(&:capitalize).
        join(' ')
    end

    def data_files(ext='txt')
      reserved_file = lambda {|x| x.to_s =~ /Log|Platemap|Troubleshooting|Proplate/ }
      Pathname.glob("**/*.#{ext}").reject(&reserved_file)
    end

    # This method perform all tasks in the SlideSet quasi-DSL. Perhaps this
    # would all be better as a granular set of Rake tasks...
    def process_data
         load_platemap and
      load_patient_log and
           load_slides and
             summarize and
         create_thumbs
    end

    def validate_structure
      all_files_exist = true

      [ :log_file, :platemap_file ].each do |f|
        file_name = SlideSet.defaults[f]
        f_exists = (directory + file_name).exist?

        if f_exists
          puts "[checking] #{file_name}... exists"
        elsif file_name =~ /platemap/i
          puts "[checking] #{file_name} does not exist, will use on-slide platemap"
          f_exists = true
        else
          puts "[error] You are missing the following file #{f}. Perhaps you need to convert it from a .xls file. #{f} should be a tab-separated values file."
        end

        all_files_exist &&= f_exists
      end

      all_files_exist
    end

    def load_platemap(file=SlideSet.defaults[:platemap_file])
      # If there is no global platemap file, assume all slides
      # in this set have the same platemap and set the first
      # slide data file as the platemap
      self.platemap = Protein.map_plate(file) || 
        Protein.map_plate(data_files[0])
    end

    def load_patient_log(file=SlideSet.defaults[:log_file])
      patients = Protein.map_log file, ','

      patients[0].each_index do |i|
        slide = patients[0][i]
        name  = patients[1][i]
        day   = patients[2][i]
        
        self.patient_log[slide] = 
          PatientSample.new(name, day) unless slide and slide.empty?
      end
    end

    def load_slides(dir=directory)
      puts "[loading] #{dir}"
      data_files.each do |path|
        self << Slide.new(path, patient_log)
      end
    end

    def add_slide(slide)
      puts "[parsing] #{slide.file.basename} -> " +
        "patient #{slide.patient_sample.name}"
      @slides << slide
    end
    alias_method :<<, :add_slide

    def summarize(file=SlideSet.defaults[:summary_file])
      buffer = [ nil, nil, nil, nil, nil ]
      columns = []
      
      columns[0] = buffer + [ 'Index' ] + (1..platemap.length).to_a
      columns[1] = [ 'Date', 'Slide', 'Print date', 'Patient', 'A/C', 'GeneID' ] + platemap
      
      puts "[summarizing] #{slides.length} patients"
      slides.sort.each do |s|
        prefix = [ s.scan_date, s.number, s.print_date, s.patient, s.day ]
      
        columns << prefix + [ "vol_total" ] + s.spot_volumes
        columns << prefix + [ "type" ] + s.spot_types
      end
  
      puts "[writing] #{file}"
      CSV.open file, 'w' do |f| 
        # Transpose columns and rows before writing, since CSV files
        # are best understood (and treated) as collections of rows,
        # not columns.
        columns.transpose.each {|row| (f << row) }
      end
      
      file
    end

    def create_thumbs(dir=SlideSet.defaults[:thumbs_directory])
      FileUtils.mkdir_p dir
      directory = Pathname.new(dir).expand_path

      slides.each do |s|
        subdir = directory + s.patient_sample.classification
        FileUtils.mkdir_p subdir.to_s

        jpg = Pathname.new(s.file.to_s.sub(/.tsv|.txt/, '.jpg'))
        if jpg.expand_path.exist?
          Dir.chdir jpg.expand_path.dirname

          puts "[resizing/labeling] #{jpg.basename} (#{s.patient_sample})"
          
          # FileUtils.cp_r(jpg.basename, directory.expand_path + jpg.basename)
          `cp "#{jpg.basename}" "#{directory.expand_path}/#{jpg.basename}"`
          Dir.chdir directory.expand_path 

          `mogrify -resize 200 "#{jpg.basename}"`
          `montage -pointsize 16 -label "Slide #{s.number} / #{s.patient_sample}" "#{jpg.basename}" -geometry +0+0 -background Gold "#{subdir + jpg.basename}"`
          `rm "#{jpg.basename}"`
        else
          puts "[warning] missing #{jpg.basename}"
        end
      end

      Dir.chdir directory
      dir
    end

    def to_s
      (slides.join "------------\n") +
        "\n\n-----------\nTotal slides: #{slides.length}\n"
    end
  end
end
