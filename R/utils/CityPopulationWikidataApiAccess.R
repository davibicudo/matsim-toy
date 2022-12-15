
get_city_population <- function(city_name, country_name) {

  # print variables used in function
  #print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  pacman::p_load("WikidataR")
  
  # search for country 
  country_q <- find_item(country_name)  
  # try to find country among first 10 results
  found_country <- F
  for (i in 1:min(10,length(country_q))) {
    country <- get_item(country_q[[i]]$id)[[1]]
    # check if found item is instance_of (P31) country (Q6256)
    if ("Q6256" %in% country$claims[["P31"]]$mainsnak$datavalue$value$id) {
      found_country <- T
      break
    }
  }
  if (!found_country) {
    stop(paste0("Could not find the country ", country_name))
  }

  # search for city
  city_q <- find_item(paste0(city_name, ", ", country_name))
  if (length(city_q) == 0 || is.null(find_city(city_q, city_name, country))) {
    message(paste0(
      "Could not find any results with '", paste0(city_name, ", ", country_name),"'",
      ". Trying with city name only ('", city_name, "')"))
    city_q <- find_item(city_name)
    city <- find_city(city_q, city_name, country)
  }
  
  pop_values <- city$claims[["P1082"]]$mainsnak$datavalue$value$amount
  pop_values <- as.numeric(substring(pop_values, 2))
  
  population <- max(pop_values)
  
  return(population)
}

# helper function
find_city <- function(city_q, city_name, country) {
  # try to find city among first 10 results
  found_city <- F
  city_is_in_country <- F
  city_has_pop <- F
  for (i in 1:min(10,length(city_q))) {
    city <- get_item(city_q[[i]]$id)[[1]]
    # check if is a city
    instance_of_municipality <- ("Q15284" %in% city$claims[["P31"]]$mainsnak$datavalue$value$id)
    instance_of_city <- ("Q515" %in% city$claims[["P31"]]$mainsnak$datavalue$value$id)
    municipality_in_description <- grepl("municipality", city$descriptions$en$value)
    city_in_description <- grepl("city", city$descriptions$en$value)
    capital_in_description <- grepl("capital", city$descriptions$en$value)
    if(any(instance_of_municipality, instance_of_city, 
           municipality_in_description, city_in_description, capital_in_description)) {
      found_city <- T
    }
    # check if the city's country match with previously found country
    country_id <- city$claims[["P17"]]$mainsnak$datavalue$value$id
    if(length(country_id) > 0 && (country_id[1] == country$id)) {
      city_is_in_country <- T
    }
    # check if city has a population tag
    if(!(is.null(city$claims[["P1082"]]))) {
      city_has_pop <- T
    }
    if(all(found_city, city_is_in_country, city_has_pop)) {
      return(city)
    }
  }
  if (!found_city) {
    message(paste0("Could not find the city ", city_name))
    return(NULL)
  }
  if (!city_is_in_country) {
    message(paste0("City ", city_name, " does not seems to be part of the country."))
    return(NULL)
  }
  if (!city_has_pop) {
    message(paste0("City ", city_name, " does not have a population tag in Wikipedia."))
    return(NULL)
  }
}

pacman::p_load("optparse")

option_list <- list(
  make_option("--city_name"),
  make_option("--country_name")
)

opt <- parse_args(OptionParser(option_list=option_list))

# get_city_population(gsub("(\")|(')","", opt$city_name), gsub("(\")|(')","", opt$country_name))

