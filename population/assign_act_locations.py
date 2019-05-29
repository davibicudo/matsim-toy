import population.r_scripts_paths as s

def configure(context, require):
    require.stage("utils.rscript")
    require.stage("population.estimate_residents_workplaces")
    require.stage("population.create_synth_pop")
    require.stage("population.calc_travel_times")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    args = ["--buildings_path="+context.stage("population.estimate_residents_workplaces")[0],
            "--pop_path="+context.stage("population.create_synth_pop"),
            "--od_rds_path="+context.stage("population.calc_travel_times")]
    
    Rscript(s.ASSIGN_ACTIVITY_LOCATIONS, 
            args, 
            cwd=context.cache_path)
    
    return "%s/pop.csv" % context.cache_path
