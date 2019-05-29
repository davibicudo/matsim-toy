import population.r_scripts_paths as s

def configure(context, require):
    require.stage("utils.rscript")
    require.stage("population.classify_buildings")
    require.stage("population.utils.get_city_pop")
    require.stage("population.utils.get_country_demographics")
    require.stage("population.utils.get_unemployment_rate")
    require.config("sample_size")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    args = ["--buildings_path="+context.stage("population.classify_buildings")[0],
            "--pt_stops_path="+context.stage("population.prepare_osm")[3],
            "--city_name='"+context.config["city_name"]+"'", 
            "--country_name='"+context.config["country_name"]+"'"]
    
    args_dict = context.args(__loader__.name)
    if "total_pop" not in args_dict:
        args += ["--total_pop="+str(context.stage("population.utils.get_city_pop"))]
    if "unemployment_rate" not in args_dict:
        args += ["--unemployment_rate="+str(context.stage("population.utils.get_unemployment_rate"))]
    if "demographics_path" not in args_dict:
        args += ["--demographics_path="+str(context.stage("population.utils.get_country_demographics"))]
        
    args += ["--sample_size="+str(context.config["sample_size"])]
    
    for k,v in args_dict.items():
        args += ['--'+str(k)+'='+str(v)]
    
    Rscript(s.ESTIMATE_RESIDENTS_WORKPLACES, 
            args, 
            cwd=context.cache_path)
    
    return ["%s/buildings.geopkg" % context.cache_path]
