import subprocess as sp
import os.path
import sys
from distutils.dir_util import copy_tree

def configure(context, require):
    require.stage("utils.java")

def execute(context):
    java_project_path = os.path.dirname(os.path.realpath(sys.argv[0]))+"/Java/"
    mvn = context.config["maven_path"]

    copy_tree(java_project_path, context.cache_path)
    
    sp.check_call([
        mvn, "package"
    ], cwd = "%s" % context.cache_path)
    
    jar = "%s/target/osm-schedule-timetable-0.0.1-SNAPSHOT-shaded.jar" % context.cache_path

    return jar

