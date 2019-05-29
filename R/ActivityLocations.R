

assign_primary_activity_locations <- function(buildings_path, pop_path, od_rds_path,
                                              sAct_share=0.5) {
  # print variables used in function
  print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  pacman::p_load("data.table", "rgdal")
  
  # read synthetic population table, buildings dataset and travel times matrix
  pop <- as.data.table(read.csv(file=pop_path))
  buildings_sp <- readOGR(dsn=buildings_path, "buildings")
  od_ttime <- readRDS(od_rds_path)
  
  # min-max normalize workplace counts in buildings
  buildings_sp$prop_wp <- 
    ifelse(is.na(buildings_sp$bd_wp), 0, buildings_sp$bd_wp/nrow(pop[pop$employed==1,]))
  
  # sample workplace. Probability = workplace_count / (travel_time)^2. 
  # overestimates for locations with disproportionate number of residents to workplaces
  pop[employed==1, c("pAct_id","pAct_x","pAct_y") := 
        buildings_sp[!is.na(buildings_sp$bd_wp),]@data[
          sample.int(nrow(buildings_sp[!is.na(buildings_sp$bd_wp),]),size=nrow(.SD),replace=T,
                     prob=buildings_sp[!is.na(buildings_sp$bd_wp),]$prop_wp),
          c("id","x","y")],
      by = home_id]
  
  # assign schools to students, closest one is chosen.
  pop[studying==1, c("pAct_id","pAct_x","pAct_y") := 
        buildings_sp@data[buildings_sp$id==
                            names(which.min(od_ttime[rownames(od_ttime)==home_id,
                                                    colnames(od_ttime) %in% buildings_sp[
                                                      which(buildings_sp$v.amenity=="school" | 
                                                              buildings_sp$v.building=="school"),]$id])),
                          c("id","x","y")],
      by = home_id]
  
  # assign an activity location to other adults (unemployed, retired) for shop or leisure
  pop[studying+employed==0 & age>=18, c("pAct_id","pAct_x","pAct_y") := 
        buildings_sp[!is.na(buildings_sp$bd_wp),]@data[
          sample.int(nrow(buildings_sp[!is.na(buildings_sp$bd_wp),]),size=nrow(.SD),replace=T,
                     prob=(buildings_sp[!is.na(buildings_sp$bd_wp),]$prop_wp/
                          (od_ttime[rownames(od_ttime)==home_id,])^1.2)), # kind of gravity model to get closer locations
          c("id","x","y")],
      by = home_id]
  
  # assign a location for secondary activity next to home
  pop[age>=12 & # only above certain age
        (((studying+employed)>=1 & # if working or studying, apply sAct_share
        sample(c(T, F), replace=T, nrow(pop), prob=c(sAct_share, 1-sAct_share))) | 
          (studying+employed)==0), # always add one sAct for unemployed/retired
      c("sAct_id","sAct_x","sAct_y") := 
        buildings_sp[!is.na(buildings_sp$bd_wp),]@data[
          sample.int(nrow(buildings_sp[!is.na(buildings_sp$bd_wp),]),size=nrow(.SD),replace=T,
                     prob=buildings_sp[!is.na(buildings_sp$bd_wp),]$prop_wp
                     /od_ttime[rownames(od_ttime)==home_id,]), # kind of gravity model to get closer locations
          c("id","x","y")],
      by = home_id]
  
  cat("\nDone assigning primary activity locations. Writing to output.")
  write.csv(pop, file="pop.csv")
  
}

pacman::p_load("optparse")

option_list <- list(
  make_option("--buildings_path"),
  make_option("--pop_path"),
  make_option("--od_rds_path"),
  make_option("--sAct_share", default=0.5)
)

opt <- parse_args(OptionParser(option_list=option_list))

assign_primary_activity_locations(
  opt$buildings_path, opt$pop_path, opt$od_rds_path, opt$sAct_share)
