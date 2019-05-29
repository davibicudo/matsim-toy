
estimate_residents_workplaces <- function(buildings_path, pt_stops_path, 
                                          city_name, country_name, 
                                          total_pop=NULL, unemployment_rate=NULL, demographics_path=NULL,
                                          sample_size=1.0,
                                          raster_cell_size=50,
                                          bus_stop_accessibility_buffer=300,
                                          train_station_accessibility_buffer=500,
                                          other_stops_accessibility_buffer=400,
                                          train_station_accessibility_factor=2,
                                          min_worker_age=18,
                                          max_worker_age=65) {
  
  # print variables used in function
  print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  pacman::p_load("rgdal", "rgeos", "raster")
  
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
  
  # apply sample size to total pop
  total_pop <- round(total_pop*sample_size)
  
  # calc employed pop
  working_age_share <- 
    sum(demographics[which(demographics$age >= min_worker_age & demographics$age < max_worker_age), "total"]) /
    sum(demographics$total)
  employed_pop <- as.numeric(round((1-unemployment_rate) * working_age_share * total_pop))
  
  # load buildings dataset
  buildings_sp <- readOGR(dsn=buildings_path, "buildings")
  
  # apply sample size to buildings (reduce number of buildings to simplify future matrix calc)
  buildings_sp <- buildings_sp[sample.int(nrow(buildings_sp), nrow(buildings_sp)*sample_size),]
  
  # load PT stops
  pt_sp <- readOGR(dsn=pt_stops_path, "stops")
  
  #### 1. Prepare base raster and grid ####
  new_rast_extent = extent(bbox(buildings_sp)) # set extent to buildings bounding box
  new_rast = raster(ext = new_rast_extent,resolution = raster_cell_size)
  new_rast[is.na(new_rast[])] <- 0
  crs(new_rast) <- crs(buildings_sp)
  grid <- as(new_rast, 'SpatialPolygonsDataFrame')
  grid$cell_id <- seq(1,nrow(grid))
  
  # linear standardization functions for transforming rasters later on
  min_max_normalization <- function(x) { 
    return((x - min(x, na.rm=T))/(max(x, na.rm=T) - min(x, na.rm=T))) 
  }
  inverse_min_max_normalization <- function(x) { 
    1-min_max_normalization(x) 
  }
  
  #### 2. Create accessibility raster from stops ####
  # set pt stop accessibility values and catchment area
  pt_sp$value <- ifelse(pt_sp$k=="train", train_station_accessibility_factor, 1)
  pt_sp$buffer <- ifelse(pt_sp$v=="bus_stop", 
                         bus_stop_accessibility_buffer, 
                         ifelse(pt_sp$k=="train", 
                                train_station_accessibility_buffer, 
                                other_stops_accessibility_buffer))
  pt_buffer <- gBuffer(pt_sp, width=pt_sp$buffer, byid=T, id=pt_sp$id)
  pt_buffer_rast <- rasterize(pt_buffer, new_rast, pt_sp$value, background=NA)
  
  # raster for walking distance to pt stop
  walk_dist <- distance(rasterize(pt_sp, new_rast, pt_sp$value))
  walk_dist_rast <- mask(walk_dist, pt_buffer)
  walk_dist_rast <- calc(walk_dist_rast, inverse_min_max_normalization)
  
  # combine into the pt raster
  pt_raster <- walk_dist_rast * pt_buffer_rast
  pt_raster <- calc(pt_raster, min_max_normalization)
  
  #### 3. Assign each building to a raster cell ####
  bd_centroids <- gCentroid(buildings_sp, byid=TRUE)
  bd_centroids <- SpatialPointsDataFrame(bd_centroids, buildings_sp@data)
  bd_centroids$cell_id <- over(bd_centroids, grid[2])[,1]
  
  #### 4. Calculate residences building volume raster ####
  # sum volumes of buildings per cell id
  bd_centroids$vol_cell_resid <- ave(bd_centroids$vol_resid, bd_centroids$cell_id, FUN = sum)
  # extract total volume of each cell
  cell_totals_resid <- aggregate(vol_cell_resid ~ cell_id, data=bd_centroids@data, FUN=max)
  # rasterize and remove cells with 0 volume
  grid_volume_resid <- merge(grid, cell_totals_resid, by="cell_id")
  vol_rast_resid <- rasterize(grid_volume_resid, new_rast, "vol_cell_resid")
  vol_rast_resid <- calc(vol_rast_resid, function(x) ifelse(x==0, NA, x))
  # linear interpolation for density
  vol_rast_resid <- calc(vol_rast_resid, min_max_normalization)
   
  #### 5. Combine rasters to estimate residences raster ####
  # combine rasters and normalize accross entire raster
  full_resid <- merge(pt_raster, new_rast) + vol_rast_resid
  full_resid <- calc(full_resid, function(x) x/sum(x, na.rm = T))
  # calculate residents raster
  resid_raster <- calc(full_resid, function(x) x*total_pop)
   
  #### 6. Assign residents from cells to buildings according to volume ####
  bd_centroids$cell_resid <- extract(resid_raster, bd_centroids)
  bd_centroids$bd_resid <- 
    bd_centroids$cell_resid*(bd_centroids$vol_resid / bd_centroids$vol_cell_resid)
  
  ##### 7. Now for workplaces. Repeat 4, 5 and 6 for estimating workplaces. ####
  # sum volumes of buildings per cell id
  bd_centroids$vol_cell_wp <- ave(bd_centroids$vol_wp, bd_centroids$cell_id, FUN = sum)
  # extract total volume of each cell
  cell_totals_wp <- aggregate(vol_cell_wp ~ cell_id, data=bd_centroids@data, FUN=max)
  # rasterize and remove cells with 0 volume
  grid_volume_wp <- merge(grid, cell_totals_wp, by="cell_id")
  vol_rast_wp <- rasterize(grid_volume_wp, new_rast, "vol_cell_wp")
  vol_rast_wp <- calc(vol_rast_wp, function(x) ifelse(x==0, NA, x))
  # linear interpolation for density
  vol_rast_wp <- calc(vol_rast_wp, min_max_normalization)
  ### Combine rasters to estimate residences and workplaces raster ###
  # combine rasters and normalize accross entire raster
  full_wp <- merge(pt_raster,new_rast) + vol_rast_wp
  full_wp <- calc(full_wp, function(x) x/sum(x, na.rm = T))
  wp_raster <- calc(full_wp, function(x) x*employed_pop)
  ### Assign residents and workplaces from cells to buildings according to volume ###
  bd_centroids$cell_wp <- extract(wp_raster, bd_centroids)
  bd_centroids$bd_wp <- 
    bd_centroids$cell_wp*(bd_centroids$vol_wp / bd_centroids$vol_cell_wp)
  
  ##### 8. Merge estimated number of residents and workplaces back to buildings vector ####
  buildings_sp <- merge(buildings_sp, bd_centroids[,c("id", "bd_resid", "bd_wp")], by="id")
  # check if totals match
  assertthat::are_equal(sum(buildings_sp$bd_resid, na.rm = T), total_pop)
  assertthat::are_equal(sum(buildings_sp$bd_wp, na.rm = T), employed_pop)
  
  cat("\nResidents and workplaces estimation done. Writing buildings to output.")
  writeOGR(buildings_sp, "buildings.geopkg", "buildings", driver="GPKG")
  
}

pacman::p_load("optparse")

option_list <- list(
  make_option("--buildings_path"),
  make_option("--pt_stops_path"),
  make_option("--city_name"),
  make_option("--country_name"),
  make_option("--total_pop", type = "integer"),
  make_option("--unemployment_rate", type = "double"), 
  make_option("--demographics_path"), 
  make_option("--sample_size", default = 1.0),
  make_option("--raster_cell_size", default = 50),
  make_option("--bus_stop_accessibility_buffer", default = 300),
  make_option("--train_station_accessibility_buffer", default = 500),
  make_option("--other_stops_accessibility_buffer", default = 400),
  make_option("--train_station_accessibility_factor", default=2),
  make_option("--min_worker_age", default = 18),
  make_option("--max_worker_age", default = 65)
)

opt <- parse_args(OptionParser(option_list=option_list))

estimate_residents_workplaces(
  opt$buildings_path, opt$pt_stops_path, opt$city_name, opt$country_name,
  opt$total_pop, opt$unemployment_rate, opt$demographics_path, 
  opt$sample_size, opt$raster_cell_size, 
  opt$bus_stop_accessibility_buffer, opt$train_station_accessibility_buffer, 
  opt$other_stops_accessibility_buffer, opt$train_station_accessibility_factor,
  opt$min_worker_age, opt$max_worker_age)
