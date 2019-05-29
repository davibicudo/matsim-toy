

create_synthetic_pop <- function(city_name, country_name, buildings_path,
                                 total_pop=NULL, unemployment_rate=NULL, demographics_path=NULL,
                                 sample_size=1.0,
                                 car_avail_rate=0.65,
                                 min_student_age=5,
                                 min_worker_age=18,
                                 max_worker_age=65,
                                 min_driver_age=18,
                                 max_driver_age=85) {
  
  # print variables used in function
  print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  pacman::p_load("data.table", "rgdal")
  
  # check input demographic data
  if (is.null(total_pop)) {
    source("utils/CityPopulationWikidataApiAccess.R")
    total_pop <- get_city_population(city_name, country_name)
  }
  if (is.null(unemployment_rate)) {
    source("utils/UnemploymentRateWorldbankApiAccess.R")
    unemployment_rate <- get_unemployment_rate(country_name)
  }
  if (is.null(demographics_path)) {
    source("utils/CountryDemographicsCensusBureauApiAccess.R")
    demographics <- get_country_demographics(country_name)
  } else {
    demographics <- read.csv(demographics_path)
  }
  
  # apply sample size to pop
  total_pop <- round(total_pop*sample_size)
  
  # calc employed pop
  working_age_share <- 
    sum(demographics[which(demographics$age >= min_worker_age & demographics$age < max_worker_age), "total"]) /
    sum(demographics$total)
  employed_pop <- as.numeric(round((1-unemployment_rate) * working_age_share * total_pop))

  # calculate proportions of each age-sex group
  ptable <- prop.table(as.matrix(demographics[,c("males", "females")]))
  age_sex <- data.frame(
    age=rep(0:((length(ptable)-1)/2),2), 
    sex=c(rep("m", length(ptable)/2), rep("f", length(ptable)/2)), 
    probabilities=as.vector(ptable))
  
  # calculate sizes of person groups
  age_sex$total <- total_pop * age_sex$probabilities
  age_sex$employed <- 
    ifelse(age_sex$age < min_worker_age | age_sex$age >= max_worker_age, 0, (1-unemployment_rate) * age_sex$total)
  age_sex$car_avail <- 
    ifelse(age_sex$age < min_driver_age | age_sex$age >= max_driver_age, 0, car_avail_rate * age_sex$total)
  age_sex$studying <- ifelse(age_sex$age < min_student_age, 0, ifelse(age_sex$age < min_worker_age, age_sex$total, 0))
  
  # load buildings dataset
  buildings_sp <- readOGR(dsn=buildings_path, "buildings")
  
  # min-max normalize resident counts in buildings
  buildings_sp$prop_residents <- 
    ifelse(is.na(buildings_sp$bd_resid), 0, buildings_sp$bd_resid/total_pop)
  
  # create pop dataframe with all persons
  pop <- setDT(age_sex)[, .(total=total, employed=employed, car_avail=car_avail, studying=studying,
                            new=rep(1,round(total))), by = .(age, sex)]
  pop[,new:=NULL]
  
  # create synthetic population data table
  pop[, c("employed","car_avail","studying","home_id","home_x","home_y") :=
        append(list(as.double(rbinom(total,1,prob=(employed/total))),
                    as.double(rbinom(total,1,prob=(car_avail/total))),
                    as.double(rbinom(total,1,prob=(studying/total)))),
               buildings_sp@data[
                 sample.int(nrow(buildings_sp),size=nrow(.SD),
                            replace=T,prob=buildings_sp$prop_residents),
                 c("id","x","y")]), 
      by = .(age, sex)]
  pop[,total:=NULL]  
  
  # reclassify variables
  pop$employed <- ifelse(pop$employed == 0, F, T)
  pop$studying <- ifelse(pop$studying == 0, F, T)
  pop$has_license <- ifelse(pop$car_avail == 0, F, T)
  pop$car_avail <- ifelse(pop$car_avail == 0, "never", "always")
  
  cat("\nDone creating synthetic population. Writing to output.")
  #if (sample_size==1.0) {
  write.csv(pop, file="pop.csv", row.names = F)
  #} else {
  #  write.csv(pop[sample.int(nrow(pop),nrow(pop)*sample_size),], file="pop.csv", row.names = F)
  #}
  
}

pacman::p_load("optparse")
  
option_list <- list(
  make_option("--city_name"),
  make_option("--country_name"),
  make_option("--buildings_path"),
  make_option("--total_pop", type = "integer"),
  make_option("--unemployment_rate", type = "double"), 
  make_option("--demographics_path"), 
  make_option("--sample_size", default = 1.0),
  make_option("--car_avail_rate", default = 0.65),
  make_option("--min_student_age", default = 5),
  make_option("--min_worker_age", default = 18),
  make_option("--max_worker_age", default = 65),
  make_option("--min_driver_age", default = 18),
  make_option("--max_driver_age", default = 85)
)

opt <- parse_args(OptionParser(option_list=option_list))

create_synthetic_pop(
  opt$city_name, opt$country_name, opt$buildings_path, 
  opt$total_pop, opt$unemployment_rate, opt$demographics_path,
  opt$sample_size, opt$car_avail_rate, 
  opt$min_student_age, opt$min_worker_age, opt$max_worker_age,
  opt$min_driver_age, opt$max_driver_age)
