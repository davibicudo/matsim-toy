import population.r_scripts_paths as s

def configure(context, require):
    require.stage("utils.rscript")
    require.stage("population.assign_act_locations")
    require.stage("population.calc_travel_times")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    args = ["--pop_path="+context.stage("population.assign_act_locations"),
            "--od_rds_path="+context.stage("population.calc_travel_times")]
    
    Rscript(s.ASSIGN_TRIP_CHAIN, 
            args, 
            cwd=context.cache_path)
    
    return "%s/pop.csv" % context.cache_path
