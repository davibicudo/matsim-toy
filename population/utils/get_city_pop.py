import population.r_scripts_paths as s

def configure(context, require):
    require.stage("utils.rscript")
    require.config("city_name")
    require.config("country_name")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    args = ["--city_name='"+context.config["city_name"]+"'", 
            "--country_name='"+context.config["country_name"]+"'"]
    
    city_pop = Rscript(s.GET_CITY_POPULATION, 
            args, 
            cwd=context.cache_path, output=True)
    
    return int(city_pop[4:-1]) 