# ---- Auto parse datetime helper -----

#' Attempt to automatically parse a character vector as a datetime.
#'
#' @param x Vector to parse (typically a character column from a data.frame).
#' @param min_success Minimum proportion of successfully parsed values in the sample
#'   required to consider converting the entire column (default: 0.8 = 80%).
#' @param sample_size Number of sampled values used to test candidate formats.
#'
#' @return
#'   - The original column if parsing is not reliable
#'   - A POSIXct vector if parsing succeeds.
auto_parse_datetime <- function(x,
                                min_success = 0.8,
                                sample_size = 200L) {
  
  # We only process columns of type character
  if (!is.character(x)) return(x)
  
  # Sample of non-NA values
  vals <- x[!is.na(x)]
  if (length(vals) == 0) return(x)
  
  vals <- head(vals, sample_size)
  
  # Common date/time formats (to be adapted as needed)
  orders <- c(
    "ymd_HMS", "ymd_HM", "ymd",
    "ymd_HMS p", "ymd_HM p",
    "mdy_HMS", "mdy_HM", "mdy",
    "mdy_HMS p", "mdy_HM p",
    "dmy_HMS", "dmy_HM", "dmy",
    "dmy_HMS p", "dmy_HM p"
  )
  
  parsed_sample <- lubridate::parse_date_time(
    vals,
    orders = orders,
    tz     = "UTC",
    quiet  = TRUE
  )
  
  success_rate <- mean(!is.na(parsed_sample))
  
  if (!is.finite(success_rate) || success_rate < min_success) {
    # Not enough values recognized → we leave the column as is
    return(x)
  }
  
  # Parsing the entire column if the success rate is sufficient
  lubridate::parse_date_time(
    x,
    orders = orders,
    tz     = "UTC",
    quiet  = TRUE
  )
}