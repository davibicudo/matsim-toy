import population.r_scripts_paths as s

def configure(context, require):
    require.stage("utils.rscript")
    require.stage("population.prepare_osm")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    args_dict = context.args(__loader__.name)
    args = ["--buildings_path="+context.stage("population.prepare_osm")[0]]
    for k,v in args_dict.items():
        args += ['--'+str(k)+'='+str(v)]
    
    Rscript(s.ESTIMATE_HEIGHTS, 
            args, 
            cwd=context.cache_path)
    
    return ["%s/buildings.geopkg" % context.cache_path]
