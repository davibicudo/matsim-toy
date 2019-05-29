import population.r_scripts_paths as s

def configure(context, require):
    require.stage("utils.rscript")
    require.config("city_name")
    require.config("country_name")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    args = ["--city_name='"+context.config["city_name"]+"'", 
            "--country_name='"+context.config["country_name"]+"'"]
    
    proj_name = Rscript(s.GET_PROJECTION_NAME, 
            args, 
            cwd=context.cache_path, 
            output=True)
    
    return str(proj_name.decode("utf-8")[5:-2]) 