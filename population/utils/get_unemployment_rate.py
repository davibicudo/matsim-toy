import population.r_scripts_paths as s

def configure(context, require):
    require.stage("utils.rscript")
    require.config("country_name")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    unemployment_rate = Rscript(s.GET_UNEMPLOYMENT_RATE, 
            ["--country_name="+context.config["country_name"]], 
            cwd=context.cache_path, output=True)
    
    return float(unemployment_rate[4:-1])