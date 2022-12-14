import population.r_scripts_paths as s
import os
import sys

def configure(context, require):
    require.stage("utils.rscript")
    require.stage("population.utils.get_osm", "osm_path")
    require.config("city_name")
    require.config("country_name")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    ktable_path = os.path.dirname(os.path.realpath(sys.argv[0]))+"/resources/POIs_Kunze.csv"
    args = ["--city_name='"+context.config["city_name"]+"'",
            "--country_name='"+context.config["country_name"]+"'",
            "--ktable_path="+ktable_path]

    args_dict = context.args(__loader__.name)
    if "osm_path" not in args_dict:
        args += ["--osm_path="+context.stage("population.utils.get_osm")]

    for k, v in args_dict.items():
        args += ['--'+str(k)+'='+str(v)]

    Rscript(s.PREPARE_OSM_DATA, 
            args, 
            cwd=context.cache_path)
    
    return ["%s/buildings.gpkg" % context.cache_path,
            "%s/POIs.gpkg" % context.cache_path,
            "%s/landuse.gpkg" % context.cache_path,
            "%s/pt_stops.gpkg" % context.cache_path]
