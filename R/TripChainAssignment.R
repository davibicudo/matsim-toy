
assign_trip_chain <- function(pop_path, od_rds_path, 
                              work_start_mean_s=8.5*3600,
                              work_start_std_s=0.5*3600,
                              work_dur_mean_s=8*3600,
                              work_dur_std_s=1.5*3600,
                              school_start_s=8*3600,
                              school_dur_s=6*3600) {
  
  # print variables used in function
  print(mget(setdiff(ls(), c("opt", "option_list", match.call()[[1]]))))
  
  pacman::p_load("data.table", "truncnorm")
  
  # read synthetic population table and travel times matrix
  pop <- as.data.table(read.csv(file=pop_path))
  od_ttime <- readRDS(od_rds_path)
  
  # sample work and school start time and duration
  pop[employed==T, c("pAct_start","pAct_dur","pAct_type") := 
        data.frame(rtruncnorm(.N, a=0, b=24*3600, mean=work_start_mean_s, sd=work_start_std_s),
                   rtruncnorm(.N, a=0, b=24*3600, mean=work_dur_mean_s, sd=work_dur_std_s),
                   "work")]
  
  pop[studying==T, `:=` (pAct_start=school_start_s, pAct_dur=school_dur_s, pAct_type="education")]
  
  # add an activity next to home to unemployed and retired
  pop[studying+employed==0 & age>=18 & !is.na(pAct_id), c("pAct_start","pAct_dur", "pAct_type") := 
        data.frame(rtruncnorm(.N, a=0, b=24*3600, mean=12*3600, sd=2*3600),
                   rtruncnorm(.N, a=0, b=24*3600, mean=2*3600, sd=2*3600),
                   sample(c("leisure", "shop"), replace=T, .N, prob=c(0.2, 0.8)))]
  
  # get freeflow car travel times from home to primary activity
  pop$pAct_ttime <- mapply(function(x,y,z) {
    ifelse(is.na(x), NA, od_ttime[rownames(od_ttime)==y, colnames(od_ttime)==z])
  }, pop$pAct_start, pop$home_id, pop$pAct_id)
  
  # set main mode based on travel time (freeflow car travel time)
  modes <- data.frame(mode=c("walk", "bike", "pt", "car"), cff_factor=c(4, 2.5, 2, 1.5))
  pop[, main_mode := "none"]
  pop[pAct_ttime <= 120, main_mode := sample(modes$mode[1:2],nrow(.SD),T,c(0.9,0.1))]
  pop[pAct_ttime > 120 & age <= 7, main_mode := modes$mode[1]]
  pop[pAct_ttime > 120 & car_avail=="never", main_mode := sample(modes$mode[1:3],nrow(.SD),T,c(0.05,0.15,0.8))]
  pop[pAct_ttime > 120 & car_avail=="always", main_mode := sample(modes$mode,nrow(.SD),T,c(0.05,0.05,0.1,0.8))]
  pop[is.na(pAct_id) & car_avail=="never", main_mode := sample(modes$mode[1:3],nrow(.SD),T,c(0.05,0.15,0.8))]
  pop[is.na(pAct_id) & car_avail=="always", main_mode := sample(modes$mode,nrow(.SD),T,c(0.05,0.05,0.1,0.8))]
  
  # set home end time
  pop$home_end <- mapply(function(x,y,z,w) {
    ifelse(is.na(x), NA, x - modes[modes$mode==w,"cff_factor"]*od_ttime[
      rownames(od_ttime)==y, colnames(od_ttime)==z])
  }, pop$pAct_start, pop$home_id, pop$pAct_id, pop$main_mode)
  
  if (nrow(pop[pop$home_end<0 & !is.na(pop$home_end),])>0) {
    message(paste0("Found ", nrow(pop[pop$home_end<0,]),
                   " (", 100*round(nrow(pop[pop$home_end<0,])/nrow(pop),3), 
                   "%) people without a route from home to primary activity. Removing these persons..."))
    pop <- pop[pop$home_end >= 0 | is.na(pop$home_end),]
  }

  # get travel time to secondary activity
  pop$sAct_ttime_ps <- mapply(function(x,y,z) {
    ifelse(is.na(x), NA, od_ttime[rownames(od_ttime)==y, colnames(od_ttime)==z])
  }, pop$sAct_id, pop$pAct_id, pop$sAct_id)
  
  # get travel time to home
  pop$sAct_ttime_sh <- mapply(function(x,y,z) {
    ifelse(is.na(x), NA, od_ttime[rownames(od_ttime)==y, colnames(od_ttime)==z])
  }, pop$sAct_id, pop$sAct_id, pop$home_id)
  
  # assign a secondary activity
  pop[!is.na(sAct_id), c("sAct_start","sAct_dur","sAct_type") := 
        data.frame(pAct_start + pAct_dur + ifelse(is.na(sAct_ttime_ps), 1, sAct_ttime_ps),
                   rtruncnorm(.N, a=0, b=24*3600, mean=1*3600, sd=1*3600),
                   sample(c("leisure", "shop"), replace=T, .N, prob=c(0.2, 0.8)))]
  
  # finish
  cat("\nDone assigning a (basic) trip chain. Writing to output.")
  write.csv(pop, file="pop.csv")
  
}


pacman::p_load("optparse")

option_list <- list(
  make_option("--pop_path"),
  make_option("--od_rds_path"),
  make_option("--work_start_mean_s", default = 8.5*3600),
  make_option("--work_start_std_s", default = 0.5*3600),
  make_option("--work_dur_mean_s", default = 8*3600),
  make_option("--work_dur_std_s", default = 1.5*3600),
  make_option("--school_start_s", default = 8*3600),
  make_option("--school_dur_s", default = 6*3600)
)

opt <- parse_args(OptionParser(option_list=option_list))

assign_trip_chain(
  opt$pop_path, opt$od_rds_path, 
  opt$work_start_mean_s, opt$work_start_std_s, 
  opt$work_dur_mean_s, opt$work_dur_std_s,
  opt$school_start_s, opt$school_dur_s)

