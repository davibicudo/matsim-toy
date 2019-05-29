
get_projection_name <- function(city_name, country_name) {
  
  # print variables used in function
  #print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  pacman::p_load("osmdata", "rgdal")
  
  bbox <- getbb(place_name=paste0(city_name, ", ", country_name), featuretype = "city", limit = 1)
  lon <- bbox[1]
  lat <- bbox[2]
  
  zone_number <- (floor((lon + 180)/6) %% 60) + 1
  if (!is.null(lat)) {
    zone_S_N <- ifelse(lat >= 0, "north", "south")
    p4s <- paste0("+proj=utm +zone=", zone_number, " +", zone_S_N, " +datum=WGS84 +units=m +no_defs")
  } else {
    p4s <- paste0("+proj=utm +zone=", zone_number, " +datum=WGS84 +units=m +no_defs")
  }
  
  return(paste0("EPSG:", showEPSG(p4s)))
}

pacman::p_load("optparse")

option_list <- list(
  make_option("--city_name"),
  make_option("--country_name")
)

opt <- parse_args(OptionParser(option_list=option_list))

get_projection_name(gsub("(\")|(')","", opt$city_name), gsub("(\")|(')","", opt$country_name))

