import population.r_scripts_paths as s

def configure(context, require):
    require.stage("utils.rscript")
    require.config("country_name")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    Rscript(s.GET_COUNTRY_DEMOGRAPHICS, 
            ["--country_name='"+context.config["country_name"]+"'"], 
            cwd=context.cache_path)
    
    return "%s/country_demographics.csv" % context.cache_path