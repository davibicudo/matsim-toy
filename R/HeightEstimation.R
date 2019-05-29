
estimate_heights <- function(buildings_path, floor_height=3.5, k=10) {
  
  # print variables used in function
  print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  # Load needed libraries
  pacman::p_load("rgeos", "FNN", "rgdal")
  
  # read buildings from previous step
  buildings_sp <- readOGR(dsn=buildings_path, "buildings")
  
  # estimate height from floors and vice-versa when possible. Assuming each floor has floor_height meters.
  buildings_sp$height <- as.numeric(as.character(buildings_sp$height))
  buildings_sp$floors <- as.numeric(as.character(buildings_sp$floors))
  buildings_sp$height <- ifelse(is.na(buildings_sp$height) & !is.na(buildings_sp$floors), 
                                buildings_sp$floors*floor_height, buildings_sp$height)
  
  ### calculate area and perimeter; and estimate missing heights and floors with k nearest neighbors
  buildings_sp$area <- gArea(buildings_sp, byid=T)
  buildings_sp$perimeter <- gLength(buildings_sp, byid=T)
  # get coordinates for knn
  bd_centroids <- gCentroid(buildings_sp,byid=T)
  buildings_sp$centroid_x <- bd_centroids@coords[,1]
  buildings_sp$centroid_y <- bd_centroids@coords[,2]
  # create train and prediction sets
  train <- buildings_sp[!is.na(buildings_sp$height),c("centroid_x", "centroid_y", "area", "perimeter")]@data
  train_predict <- buildings_sp[is.na(buildings_sp$height),c("centroid_x", "centroid_y", "area", "perimeter")]@data
  heights <- buildings_sp[!is.na(buildings_sp$height),"height"]@data[,1]
  # run KNN to check R-squared first and then get predictions
  knn_cv <- knn.reg(train=train, y=heights, k=k)
  print(knn_cv)
  knn <- knn.reg(train=train, test=train_predict, y=heights, k=k)
  
  buildings_sp[is.na(buildings_sp$height),"height"] <- knn$pred
  
  cat("\nHeights estimation done. Writing to output.")
  writeOGR(buildings_sp, "buildings.geopkg", "buildings", driver="GPKG")

}

pacman::p_load("optparse")

option_list <- list(
  make_option("--buildings_path"),
  make_option("--floor_height", default = 3.5),
  make_option("--k", default = 10)
)

opt <- parse_args(OptionParser(option_list=option_list))

estimate_heights(opt$buildings_path, opt$floor_height, opt$k)

