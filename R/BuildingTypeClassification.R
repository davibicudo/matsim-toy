
classify_building_types <- function(buildings_path, pois_path, landuse_path, 
                                    ktable_path="../resources/POIs_Kunze.csv",
                                    max_resid_building_area=2000,
                                    min_usable_building_area=50,
                                    residential_share_mixed_buildings=0.5) {
  
  # print variables used in function
  print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  pacman::p_load("rgdal", "sp", "rgeos")
  
  # read OSM prepared features
  buildings_sp <- readOGR(dsn=buildings_path, "buildings")
  poi_sp_buffer <- readOGR(dsn=pois_path, "poi")
  ls_sp <- readOGR(dsn=landuse_path, "landuse")

  # read 2015_Kunze's appendix table
  ktable <- read.csv2(ktable_path, stringsAsFactors = F) #TODO fix path
  
  ### add landuse tag to buildings
  buildings_sp$landuse <- over(buildings_sp, ls_sp[3])$v
  
  ### check which buildings has a POI
  row.names(buildings_sp@data) <- seq(1,nrow(buildings_sp))
  ov <- over(buildings_sp, poi_sp_buffer)
  ov$has_poi <- !is.na(ov$id)
  cnames <- colnames(buildings_sp@data)
  buildings_sp <- cbind(buildings_sp, ov[,"has_poi"])
  colnames(buildings_sp@data) <- c(cnames, "has_poi")
  
  ### Calculate building types and volumes ###
  # types can be: residential, workplace or mixed
  # TODO improve idle type 0/0 %
  non_resid <- ktable[which(ktable$Non.residential.floor.value..nrfv. == "sn"),"OSM.Value"]
  buildings_sp$type <- 
    ifelse(
      buildings_sp$v.building %in% non_resid  |
        buildings_sp$v.amenity %in% non_resid |
        buildings_sp$v.shop %in% non_resid |
        buildings_sp$landuse %in% c("industrial", "farmland", "forest", "grass", "meadow", "farmyard") |
        buildings_sp$area > max_resid_building_area,
      "workplace",
      ifelse(
        buildings_sp$landuse %in% c("commercial","retail") |
          buildings_sp$has_poi |
          !(buildings_sp$v.building %in% c("yes","residential","house","detached")) |
          !is.na(buildings_sp$v.amenity) |
          !is.na(buildings_sp$v.shop),
        "mixed",
        ifelse(
          buildings_sp$area < min_usable_building_area,
          "idle",
          "residential"
        )
      )
    )
  t <- table(buildings_sp@data$type, exclude = NULL)
  cat("\nClassification done. Types: \n")
  cat(names(t))
  cat(paste0("\n",t))
  
  # calculate volumes based on area, height and types
  buildings_sp$vol_resid <- 
    ifelse(
      buildings_sp$type=="residential", 
      buildings_sp$height*buildings_sp$area, 
      ifelse(
        buildings_sp$type=="mixed",
        residential_share_mixed_buildings*buildings_sp$height*buildings_sp$area, 
        0
      )
    )
  buildings_sp$vol_wp <- 
    ifelse(
      buildings_sp$type=="workplace", 
      buildings_sp$height*buildings_sp$area, 
      ifelse(
        buildings_sp$type=="mixed",
        (1-residential_share_mixed_buildings)*buildings_sp$height*buildings_sp$area, 
        0
      )
    )
  
  cat("\nClassification and volume calculation done. Writing buildings to output.")
  
  writeOGR(buildings_sp, "buildings.geopkg", "buildings", driver="GPKG")
  
}


pacman::p_load("optparse")

option_list <- list(
  make_option("--buildings_path"),
  make_option("--pois_path"),
  make_option("--landuse_path"),
  make_option("--ktable_path"),
  make_option("--max_resid_building_area", default = 2000),
  make_option("--min_usable_building_area", default = 50),
  make_option("--residential_share_mixed_buildings", default = 0.5)
)

opt <- parse_args(OptionParser(option_list=option_list))

classify_building_types(
  opt$buildings_path, opt$pois_path, opt$landuse_path, opt$ktable_path,
  opt$max_resid_building_area, opt$min_usable_building_area, 
  opt$residential_share_mixed_buildings)
