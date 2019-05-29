
calc_travel_times <- function(buildings_path) {
  
  # print variables used in function
  print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  pacman::p_load("rgeos", "rgdal", "dodgr")
  
  # load buildings dataset
  buildings_sp <- readOGR(dsn=buildings_path, "buildings")
  
  cat("\nCalculating travel time matrix...")
  
  # buildings OD-pairs for routing
  bd <- gCentroid(buildings_sp, byid=TRUE)
  bd <- SpatialPointsDataFrame(bd, buildings_sp@data)
  bd <- spTransform(bd, CRS("+init=epsg:4326")) # back to wgs 84
  from <- bd[!is.na(bd$bd_resid),]@coords # rownames reference building IDs
  to <- bd[!is.na(bd$bd_wp),]@coords
  
  # weighting profiles for OSM highway types
  # speeds as in https://github.com/matsim-org/matsim/blob/258a7d04b1ec7851aabafa08989497c6992c8972/matsim/src/main/java/org/matsim/core/utils/io/OsmNetworkReader.java
  wp <- data.frame(name=rep("motorcar",14),
                   way=c("motorway", "motorway_link", "trunk", "trunk_link",
                         "primary", "primary_link", "secondary", "secondary_link",
                         "tertiary", "tertiary_link", "minor", "unclassified",
                         "residential", "living_street"),
                   value=c(120,80,80,50, 
                           80,60,60,60,
                           45,45,45,45,
                           30,15))
  wp$value <- wp$value/3600 # convert to km/s 
  
  # obtain graph (major component, weighted). Weighted distances are seconds to travel through link
  roadnet <- dodgr_streetnet(pts = rbind(from,to), expand = 0.1) 
  roadnet <- roadnet[roadnet$highway %in% wp$way,]
  carnet <- weight_streetnet(roadnet, wt_profile = wp)
  carnet <- carnet [which (carnet$component == 1), ]
  
  # get OSM nearest nodes for buildings
  gr_cols <- dodgr:::dodgr_graph_cols (carnet)
  vert_map <- dodgr:::make_vert_map (carnet, gr_cols) # map indexing node IDs
  from_index <- dodgr:::get_index_id_cols(carnet, gr_cols, vert_map, from) # find vertices nearest to coords
  to_index <- dodgr:::get_index_id_cols(carnet, gr_cols, vert_map, to) 
  nearest_nodes <- vert_map[c(from_index$index, to_index$index),"vert"]
  
  # contract graph to speed up calculations
  carnet_simplified <- dodgr_contract_graph(carnet, nearest_nodes)$graph
  
  # calculate distances matrix (some tricks for the library to return seconds rather than dist as output)
  colnames(carnet_simplified)[colnames(carnet_simplified) == 'd_weighted'] <- 'dist'
  colnames(carnet_simplified)[colnames(carnet_simplified) == 'd'] <- 'meter_dist'
  carnet_simplified[,c("geom_num","highway", "way_id")] <- NULL 
  od_ttime <- dodgr_dists(carnet_simplified, from = from, to = to)
  
  # replace NAs with a large value and 0's with a small value for further calculations
  od_ttime[is.na(od_ttime)] <- 3600000
  od_ttime[od_ttime==0] <- 0.001
  
  cat("\nCalculating travel time matrix done. Writing to output.\n")
  saveRDS(od_ttime, "od_ttime_matrix.rds")
}

pacman::p_load("optparse")

option_list <- list(
  make_option("--buildings_path")
)

opt <- parse_args(OptionParser(option_list=option_list))

calc_travel_times(opt$buildings_path)
