# wilcoxon.r - Quick Wilcoxon test for NAPPA data
# by David Jacobs 2010

# Apply the two-sided Wilcoxon signed-rank test to each variable in
# a data frame, limiting analysis to the samples listed in sample.ids
# (should only be two numbers).
wilcox.subset <- function(my.data, sample.ids, stat="p.value", alt) {
  lapply(my.data, function(x) {
    wilcox.test(x ~ sample, data=my.data, alternative=alt,
      subset=sample %in% sample.ids)[[stat]]
  })
}

# Return results from a Wilcoxon subset test as a matrix
wilcox.subset.as.matrix <- function(...) {
  as.matrix(wilcox.subset(...))
}

# Apply the two-sided Wilcoxon signed-rank test column-by-column to each
# variable of a data frame. Only samples listed in sample.ids (should be
# exactly two numbers) will be analyzed. This method extracts
# the Wilcoxon rank and p-value for each column and returns it as a
# data frame.
wilcox.quick <- function(my.data, sample.ids, alt) {
  
  # Perform the Wilcoxon signed rank test on my.data, extracting
  # the rank and p-values
  stats <- wilcox.subset.as.matrix(my.data, sample.ids, "statistic", alt)
  p.value <- wilcox.subset.as.matrix(my.data, sample.ids, "p.value", alt)

  # Format the results
  stats.formatted <- format(stats, digits=5, nsmall=2)
  p.value.formatted <- format(p.value, digits=1, nsmall=3)

  # Store the results in a data frame
  agg.data <- rbind(as.numeric(stats.formatted), as.numeric(p.value.formatted))

  # Add appropriate row and column names
  rownames(agg.data) <- c("w", "p")
  colnames(agg.data) <- paste(colnames(my.data))

  # Return the results
  agg.data
}

# Imports sample data from filename and returns it in a standardized
# format
wilcox.import <- function(filename, transpose=FALSE) {
  raw.data <- read.csv(filename, header=TRUE)
  
  if(transpose == TRUE) {
    my.data <- data.frame(t(raw.data))
    colnames(my.data) <- my.data[1,]
    my.data[1,] <- NULL
  }
  else {
    my.data <- raw.data
  }
  
  my.data[,1] <- NULL
  my.data
}

# Applies the two-sided Wilcoxon signed-rank test to a file formatted in
# a specific way. The sample name should be in the first column and will
# not be used. The sample number should be in a second column named
# "Sample". Sample numbers should be consecutive and may be repeated.
# The remaining columns are dependent variables whose value may have
# changed between samples. (Samples are "treatments" specified in the
# Wilcoxon signed-rank test.) This method outputs a series of files
# comparing each sample with every other sample. For each comparison,
# a file is output with the Wilcoxon rank and p-value listed for each
# variable. If the input file's rows and columns are oriented in the
# opposite way (ie, variables are rows), set the value of
# "transpose" to TRUE.
wilcox.with.file <- function(filename, transpose=FALSE, alternative="greater") {
  my.data <- wilcox.import(filename, transpose)

  # Determine how many samples we're dealing with
  sample.num <- max((rle(my.data$sample))$values)

  # For each sample ...  
  for(i in 1:sample.num) {
    for(j in 1:sample.num) { 

      # If we haven't compared the two samples yet, and they are not
      # identical ...
      if(i < j) {
      
        # ... construct an output file name and compare the two samples
        # using the Wilcoxon test (two-sided)
        out.file <- paste("samples-", i, "-and-", j, "-",
          alternative, ".csv", sep="")
        
        wilcox.data <- t(wilcox.quick(my.data, c(i,j), alt=alternative))
        colnames(wilcox.data) <- c("w","p")
        # wilcox.data[1,] <- NULL
        
        # Write the file in standard CSV format, with data
        # separated by commas
        write.csv(wilcox.data, file=out.file, sep=",")
      }
    }
  }
}
