

get_osm_data <- function(city_name, country_name) {
  
  # print variables used in function
  print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  # load needed libraries
  pacman::p_load("osmdata")
  
  # get bounding box for city
  bbox <- getbb(place_name=paste0(city_name, ", ", country_name), featuretype = "city", limit = 1)
  #bbox [1, ] <- bbox [1, ] + c (-0.05, 0.05) * diff (bbox [1, ])
  #bbox [2, ] <- bbox [2, ] + c (-0.05, 0.05) * diff (bbox [2, ])
  
  osm_query <- opq(bbox, timeout = 6000, memsize = 1e9) %>%
    add_osm_feature("highway")
  osm_query$suffix <- gsub(">;", "<;>;", osm_query$suffix) # up and down OSM member recursion
  osm_query$features <- ""
  osm_query <- opq_string(osm_query)
  
  # run query to get osm data from overpass api
  cat("Downloading OSM data...")
  osmdata_xml(osm_query, "osm_data.osm", encoding = 'utf-8')
  #doc <- osmdata:::overpass_query (query = osm_query, quiet = T, encoding = 'utf-8')
  #fileConn <- file("osm_data.osm")
  #writeLines(doc, fileConn)
  #close(fileConn)
  cat("Done")

}

pacman::p_load("optparse")

option_list <- list(
  make_option("--city_name"),
  make_option("--country_name")
)

opt <- parse_args(OptionParser(option_list=option_list))

get_osm_data(gsub("(\")|(')","", opt$city_name), gsub("(\")|(')","", opt$country_name))

