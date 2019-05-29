import population.r_scripts_paths as s

def configure(context, require):
    require.stage("utils.rscript")
    require.stage("population.estimate_residents_workplaces")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    Rscript(s.CALC_TRAVEL_TIMES, 
            ["--buildings_path="+context.stage("population.estimate_residents_workplaces")[0]], 
            cwd=context.cache_path)
    
    return "%s/od_ttime_matrix.rds" % context.cache_path
