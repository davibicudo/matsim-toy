import os.path

def configure(context, require):
    require.stage("matsim.java.pt2matsim")
    require.stage("utils.java")
    require.stage("population.utils.get_osm", "osm_path")

def execute(context):
    jar = context.stage("matsim.java.pt2matsim")
    java = context.stage("utils.java")

    # Create MATSim schedule

    java(jar, "org.matsim.pt2matsim.run.Osm2TransitSchedule", [
        "%s" % context.stage("population.utils.get_osm", "osm_path"),
        "%s/transit_schedule.xml.gz" % context.cache_path,
        context.stage("population.utils.get_projection_name")
    ], cwd = context.cache_path)

    assert(os.path.exists("%s/transit_schedule.xml.gz" % context.cache_path))

    return {
        "schedule" : "%s/transit_schedule.xml.gz" % context.cache_path
    }
