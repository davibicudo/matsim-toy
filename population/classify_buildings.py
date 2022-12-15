import population.r_scripts_paths as s
import sys
import os

def configure(context, require):
    require.stage("utils.rscript")
    require.stage("population.prepare_osm")
    require.stage("population.estimate_heights")

def execute(context):
    
    Rscript = context.stage("utils.rscript")
    
    ktable_path = os.path.dirname(os.path.realpath(sys.argv[0]))+"/resources/POIs_Kunze.csv"
    args = ["--buildings_path="+context.stage("population.estimate_heights")[0],
            "--pois_path="+context.stage("population.prepare_osm")[1],
            "--landuse_path="+context.stage("population.prepare_osm")[2],
            "--ktable_path="+ktable_path]
    args_dict = context.args(__loader__.name)
    for k,v in args_dict.items():
        args += ['--'+str(k)+'='+str(v)]
    
    Rscript(s.CLASSIFY_BUILDING_TYPES, 
            args, 
            cwd=context.cache_path)
    
    return ["%s/buildings.gpkg" % context.cache_path]
