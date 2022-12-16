

get_country_demographics <- function(country_name, output=T) {
  
  # print variables used in function
  print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  pacman::p_load(jsonlite, ISOcodes)

  ISO_code <- ISO_3166_1[agrepl(country_name, ISO_3166_1$Name),1]
  base_url <- "https://api.census.gov/data/timeseries/idb/1year?get=AGE,POP,SEX&time="
  current_year <- substr(Sys.Date(), 1, 4)
  
  demographics <- fromJSON(paste0(base_url,current_year,"&FIPS=",ISO_code))
  colnames(demographics) <- demographics[1,]
  demographics <- as.data.frame(demographics[-1,-5], stringsAsFactors=F)
  demographics <- as.data.frame(lapply(demographics, as.numeric))
  demographics <- demographics[demographics$SEX %in% c(1,2),]
  demographics$SEX <- ifelse(demographics$SEX == 1, "male", "female")
  
  demographics$males <- ifelse(demographics$SEX == "male", demographics$POP, 0)
  demographics$females <- ifelse(demographics$SEX == "female", demographics$POP, 0)
  
  demographics <- cbind(demographics[demographics$SEX=="male",c("AGE","males")], 
                        demographics[demographics$SEX=="female","females"])
  
  colnames(demographics) <- c("age", "males", "females")
  demographics$total <- demographics$males + demographics$females
  
  cat("Writing demographics to file.")
  write.csv(demographics, "country_demographics.csv", row.names = F)
  
  if (output) {
    return(demographics)
  }
}


pacman::p_load("optparse")

option_list <- list(
  make_option("--country_name"),
  make_option("--display", default = F)
)

opt <- parse_args(OptionParser(option_list=option_list))

get_country_demographics(gsub("(\")|(')","", opt$country_name), opt$display)

