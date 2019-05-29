
get_unemployment_rate <- function(country_name) {
  
  # print variables used in function
  #print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  pacman::p_load("WDI", "ISOcodes")
  
  ISO_code <- ISO_3166_1[agrepl(country_name, ISO_3166_1$Name),1]
  if (length(ISO_code) == 0) {
    stop(paste0("Could not find ISO code for: ", country_name, ". Hint: country names are expected in english."))
  }
  
  current_year <- as.numeric(substr(Sys.Date(), 1, 4))
  df <- WDI(country = ISO_code, indicator = "SL.UEM.TOTL.ZS", start=current_year-1, end=current_year)
  unemployment_rate <- as.numeric(df$SL.UEM.TOTL.ZS/100)
  
  return(unemployment_rate)
}

pacman::p_load("optparse")

option_list <- list(
  make_option("--country_name")
)

opt <- parse_args(OptionParser(option_list=option_list))

get_unemployment_rate(gsub("(\")|(')","", opt$country_name))

