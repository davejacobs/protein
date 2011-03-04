module Protein
  # Represents a patient sample, which consists of a patient name
  # along with the day on which the sample was taken. The day function
  # of this class is useful for normalizing day output, even with
  # varying inputs.
  class PatientSample
    attr_accessor :name, :day, :classification

    def initialize(n, d, classification=nil)
      @name, @day = n, d
      @classification = classification || guess_classification_from(n)
    end

    def guess_classification_from(n)
      case n
      when /IDX/
        'Index'
      when /VAC/i
        'Vacinee'
      when /NA\d+/i
        'North American'
      else
        'Quality Control'
      end
    end    

    def day
      @day ||= ''

      case @day.to_s
      when '2', 'acute', 'A', '0'
        'A'
      when '7', 'convalescent', 'C', '21'
        'C'
      end
    end

    def to_s
      day ? "#{name} #{day}" : name
    end
  end
end
