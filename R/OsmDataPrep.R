# Estimation of inhabitants and workplaces per OSM building

prepare_osm_data <- function(osm_path, city_name, country_name, sample_size=1.0,
                             ktable_path="../resources/POIs_Kunze.csv") {
  
  # print variables used in function
  print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  # Load needed libraries
  pacman::p_load("osmar", "rgeos", "rgdal", "sf", "osmdata")
  
  ##### Load and pre-process data from OSM #####
  cat("\nParsing OSM data...")
  ua <- get_osm(complete_file(), source = osmsource_file(osm_path))
  cat("\nDone")
  
  # read 2015_Kunze's appendix table
  ktable <- read.csv2(ktable_path, stringsAsFactors = F)
  
  ### prepare Buildings ###
  # get buildings from OSM and respective nodes. Sample buildings.
  bd_ids <- find(ua, way(tags(k %agrep% "building")))
  bd_ids <- sample(bd_ids, sample_size*length(bd_ids))
  bd_ids <- find_down(ua, way(bd_ids))
  bd <- subset(ua, ids = bd_ids)
  
  # filter to keep only buildings within city's perimeter
  borders <- getbb(place_name=paste(city_name, country_name, sep=","), format_out="sf_polygon", limit=1, featuretype="city")
  nodes <- bd$nodes$attrs[, c("id","lat","lon")]
  nodes <- st_as_sf(nodes, coords=c("lon","lat"), crs="+proj=longlat +datum=WGS84")
  if (class(borders) == "list") {
    borders <- borders$multipolygon
  }
  nodes_i <- st_intersection(nodes, borders)
  if (nrow(nodes_i)==0) {
    message(paste0("Border found for ", city_name, ", ", country_name, " does not overlap with OSM data. 
                   Original bounding box shall be kept and this might lead to city population and 
                   workplaces being distributed outside the city's borders."))
  } else {
    bd_ids <- find_up(ua, node(nodes$id))
    bd_ids <- find_down(ua, way(bd_ids$way_ids))
    bd <- subset(ua, ids = bd_ids)
  }
  
  # include osm relevant tags
  buildings <- subset(bd$ways$tags, k %in% c("building","amenity","shop"))
  buildings <- subset(buildings, v %in% c("yes", unlist(ktable[2])))
  buildings <- reshape(buildings, idvar= "id", timevar = "k", direction = "wide")
  buildings <- droplevels(buildings) # update factor levels
  
  # add height and floor values from OSM tags. 
  buildings <- merge(buildings, subset(bd$ways$tags, k=="height", select=c("id","v")), by="id", all.x=T)
  buildings <- merge(buildings, subset(bd$ways$tags, k=="building:levels", select=c("id","v")), by="id", all.x=T)
  names(buildings)[names(buildings) == 'v.x'] <- 'height'
  names(buildings)[names(buildings) == 'v.y'] <- 'floors'
  
  # convert to spdf 
  cat("\nConverting buildings to polygons...")
  buildings_sp <- as_sp(bd, "polygons")
  buildings_sp <- SpatialPolygonsDataFrame(
    subset(buildings_sp, id %in% buildings$id), data = subset(buildings, id %in% buildings_sp$id), match.ID = "id")
  
  # find the correct UTM zone and re-project
  bbox <- buildings_sp@bbox
  zone_number <- (floor((bbox[1] + 180)/6) %% 60) + 1
  zone_S_N <- ifelse(bbox[2] >= 0, "north", "south")
  proj4s <- paste0("+proj=utm +zone=", zone_number, " +", zone_S_N, " +datum=WGS84 +units=m +no_defs")
  buildings_sp <- spTransform(buildings_sp, CRS(proj4s))
  cat("\nDone.")
  
  ### prepare POIs for later step ###
  # get nodes that could be building POIs based on Kunze's tags and remove irrelevant k-v pairs
  poiN_ids <- find(ua, node(tags(k %in% unlist(ktable[1]))))
  poiN <- subset(ua, node_ids = poiN_ids)
  poi <- poiN$nodes$tags
  poi <- subset(poi, k %in% unlist(ktable[1]))
  poi <- subset(poi, v %in% unlist(ktable[2]))
  poi <- reshape(poi, idvar= "id", timevar = "k", direction = "wide")
  poi <- droplevels(poi) # update factor levels
  cat("Pois to spdf")
  # convert POIs to spdf and apply buffer for intersecting with buildings
  poiN <- subset(ua, node_ids = poi$id)
  poi_sp <- as_sp(poiN, "points")
  poi_sp <- SpatialPointsDataFrame(poi_sp, data = poi, match.ID = "id")
  poi_sp <- spTransform(poi_sp, CRS(proj4s))
  poi_sp_buffer <- gBuffer(poi_sp, width=2, byid=T, id=poi_sp$id)
  cat("LU to spdf")
  ### prepare Landuse ###
  # get land use areas and respective nodes
  ls_ids <- find(ua, way(tags(k %agrep% "landuse")))
  ls_ids <- find_down(ua, way(ls_ids))
  ls <- subset(ua, ids = ls_ids)
  
  # convert land use to sp features
  dat <- subset(ls$ways$tags, k=="landuse")
  dat <- droplevels(dat) # update factor levels
  ls_sp <- as_sp(ls, "polygons")
  ls_sp <- SpatialPolygonsDataFrame(
    subset(ls_sp, id %in% dat$id), data = subset(dat, id %in% ls_sp$id), match.ID = "id")
  ls_sp <- spTransform(ls_sp, CRS(proj4s))
  cat("PT to spdf")
  ### Prepare PT stops ###
  # get stops ids
  pt_ids <- c(find(ua, node(tags(v %grep% "bus_stop"))), 
              find(ua, node(tags(v %grep% "stop_position"))))
  pt <- subset(ua, node_ids = pt_ids)
  
  # subset stops for main modes
  busstops <- subset(pt$nodes$tags, v=="bus_stop")
  trainstops <- subset(pt$nodes$tags, k %in% c("public_transport", "train"))
  trainstops <- subset(trainstops, v %in% c("stop_position", "yes"))
  trainstops <- trainstops[trainstops$k=="train",]
  ferrystops <- subset(pt$nodes$tags, k %in% c("public_transport", "amenity"))
  ferrystops <- subset(ferrystops, v %in% c("stop_position", "ferry_terminal"))
  ferrystops <- ferrystops[ferrystops$k=="amenity",]
  
  # convert pt stops to sp features
  dat <- rbind(busstops, trainstops, ferrystops)
  dat <- droplevels(dat) # update factor levels
  if (sum(duplicated(dat$id)) != 0) {
    cat(paste0("Dropping ", sum(duplicated(dat$id)), " PT stations with duplicated OSM ID."))
    dat <- dat[!duplicated(dat$id),]
  }
  pt_dat <- subset(ua, node_ids = dat$id)
  pt_sp <- SpatialPointsDataFrame(as_sp(pt_dat, "points"), data = dat, match.ID = "id")
  pt_sp <- spTransform(pt_sp, CRS(proj4s))

  # All done  
  cat("\nOSM data preparation done. Writing to output.")
  
  writeOGR(buildings_sp, "buildings.gpkg", "buildings", driver="GPKG")
  writeOGR(poi_sp_buffer, "POIs.gpkg", "poi", driver="GPKG")
  writeOGR(ls_sp, "landuse.gpkg", "landuse", driver="GPKG")
  writeOGR(pt_sp, "pt_stops.gpkg", "stops", driver="GPKG")
  
}


pacman::p_load("optparse")

option_list <- list(
  make_option("--osm_path"),
  make_option("--city_name"),
  make_option("--country_name"),
  make_option("--sample_size", default = 1.0),
  make_option("--ktable_path")
)

opt <- parse_args(OptionParser(option_list=option_list))

prepare_osm_data(
  opt$osm_path, opt$city_name, opt$country_name, opt$sample_size, opt$ktable_path)

  