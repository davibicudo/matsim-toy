import population.r_scripts_paths as s
import os
import sys

def configure(context, require):
    require.stage("utils.rscript")
    require.stage("population.utils.get_osm")
    require.config("city_name")
    require.config("country_name")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    ktable_path = os.path.dirname(os.path.realpath(sys.argv[0]))+"/resources/POIs_Kunze.csv"
    args = ["--osm_path="+context.stage("population.utils.get_osm"),
            "--city_name='"+context.config["city_name"]+"'", 
            "--country_name='"+context.config["country_name"]+"'",
            "--ktable_path="+ktable_path]
    
    Rscript(s.PREPARE_OSM_DATA, 
            args, 
            cwd=context.cache_path)
    
    return ["%s/buildings.geopkg" % context.cache_path,
            "%s/POIs.geopkg" % context.cache_path,
            "%s/landuse.geopkg" % context.cache_path,
            "%s/pt_stops.geopkg" % context.cache_path]
