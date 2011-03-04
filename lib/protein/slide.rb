require 'protein/patient_sample'

module Protein
  class Slide
    attr_accessor :number, :print_date, :scan_date, :patient,
      :day, :patient_sample, :gain, :spots, :spot_volumes, :spot_types, :file

    def initialize(file, patient_log)
      @file = Pathname.new(file).expand_path
      @print_date, @number, @gain = Protein.parse_scan_file_name(file.basename)

      # Scan parent directory name for *scan date*, but *experiment date*
      # is possibly different (in the case of rescanning) and is recorded
      # in the Log.tsv file
      @scan_date, @scan_description = Protein.parse_scan_folder_name(file.dirname)
      
      @patient_sample = patient_log[@number]
      @patient = @patient_sample.name
      @day = @patient_sample.day

      # I should change this to determine whether there is a GeneId
      # (extra) column due to platemap. As it is, this determines the
      # MicroVigene version number, since I was not able to use
      # platemaps with versions before 4.
      microvigene = cell(file, 0, 2)

      volume_column = (microvigene.to_i == 4000 ? 9 : 8)
      type_column = (microvigene.to_i == 4000 ? 13 : 12)

      @spot_volumes = col(file, volume_column, 6)
      @spot_types = col(file, type_column, 6)
    end

    def <=>(other)
      self.number.to_i <=> other.number.to_i
    end

    def to_s
      <<-HERE
      Slide number: #{@number}
      Print date: #{@print_date}
      Patient: #{@patient_sample}
      Scan date: #{@scan_date} (gain #{@gain.to_s})
      Array size: #{@spot_volumes.length}
      HERE
    end
  end
end
