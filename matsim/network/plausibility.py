import os.path

def configure(context, require):
    require.stage("matsim.java.pt2matsim")
    require.stage("matsim.network.add_timetable")
    require.stage("matsim.network.mapped")
    require.stage("utils.java")
    require.stage("population.utils.get_projection_name")

def execute(context):
    java = context.stage("utils.java")
    jar = context.stage("matsim.java.pt2matsim")
    schedule = context.stage("matsim.network.add_timetable")["schedule"]
    network = context.stage("matsim.network.mapped")["network"]

    # Do plausibility checks

    java(jar, "org.matsim.pt2matsim.run.CheckMappedSchedulePlausibility", [
        schedule, network, context.stage("population.utils.get_projection_name"), context.cache_path
    ], cwd = context.cache_path)

    assert(os.path.exists("%s/allPlausibilityWarnings.csv" % context.cache_path))
    return context.cache_path
