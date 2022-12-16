import population.r_scripts_paths as s

def configure(context, require):
    require.stage("utils.rscript")
    require.stage("population.estimate_residents_workplaces")
    require.stage("population.utils.get_osm", "osm_path")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    args = ["--buildings_path="+context.stage("population.estimate_residents_workplaces")[0]]
    
    args_dict = context.args(__loader__.name)
    if "osm_path" not in args_dict:
        args += ["--osm_path="+context.stage("population.utils.get_osm")]
      
    for k, v in args_dict.items():
        args += ['--'+str(k)+'='+str(v)]
    
    Rscript(s.CALC_TRAVEL_TIMES, 
            args, 
            cwd=context.cache_path)
    
    return "%s/od_ttime_matrix.rds" % context.cache_path
