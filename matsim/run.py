import shutil
import os.path

def configure(context, require):
    require.stage("matsim.network.mapped")
    require.stage("matsim.network.add_timetable")
    require.stage("matsim.population")
    require.stage("utils.java")
    require.stage("population.utils.get_projection_name")
    require.config("sample_size")

def execute(context):
    network_path = context.stage("matsim.network.mapped")["network"]
    shutil.copyfile(network_path, "%s/network.xml.gz" % context.cache_path)

    transit_schedule_path = context.stage("matsim.network.add_timetable")["schedule"]
    shutil.copyfile(transit_schedule_path, "%s/transit_schedule.xml.gz" % context.cache_path)

    transit_vehicles_path = context.stage("matsim.network.add_timetable")["vehicles"]
    shutil.copyfile(transit_vehicles_path, "%s/transit_vehicles.xml.gz" % context.cache_path)

    input_population_path = context.stage("matsim.population")
    shutil.copyfile(input_population_path, "%s/population.xml.gz" % context.cache_path)

    # change config settings
    args_dict = context.args(__loader__.name)
    
    this_path = os.path.dirname(os.path.abspath(__file__))
    
    config = open("%s/config_template.xml" % this_path).read()
    
    config = config.replace(
        '<param name="coordinateSystem" value="Atlantis" />',
        '<param name="coordinateSystem" value="%s" />' % context.stage("population.utils.get_projection_name")
    )
    config = config.replace(
        '<param name="numberOfThreads" value="8" />',
        '<param name="numberOfThreads" value="%d" />' % context.config["threads"]
    )
    config = config.replace(
        '<param name="flowCapacityFactor" value="1.0" />',
        '<param name="flowCapacityFactor" value="%s" />' % str(float(context.config["sample_size"]))
    )
    config = config.replace(
        '<param name="storageCapacityFactor" value="1.0" />',
        '<param name="storageCapacityFactor" value="%s" />' % str(1/float(context.config["sample_size"]))
    )
    if args_dict.get("lastIteration") is not None:
        config = config.replace(
            '<param name="lastIteration" value="100" />',
            '<param name="lastIteration" value="%d" />' % args_dict.get("lastIteration")
        )
    if args_dict.get("writeEventsInterval") is not None:
        config = config.replace(
            '<param name="writeEventsInterval" value="10" />',
            '<param name="writeEventsInterval" value="%d" />' % args_dict.get("writeEventsInterval")
        )
    if args_dict.get("writePlansInterval") is not None:
        config = config.replace(
            '<param name="writePlansInterval" value="10" />',
            '<param name="writePlansInterval" value="%d" />' % args_dict.get("writePlansInterval")
        )
    if args_dict.get("writeSnapshotsInterval") is not None:
        config = config.replace(
            '<param name="writeSnapshotsInterval" value="1" />',
            '<param name="writeSnapshotsInterval" value="%d" />' % args_dict.get("writeSnapshotsInterval")
        )
    
    with open("%s/config.xml" % context.cache_path, "w+") as f:
        f.write(config)
    
    java = context.stage("utils.java")

    java(
        context.stage("matsim.java.add_timetable_compile"), "mtoy.MatsimRaptorControler",
        ["config.xml"], cwd = context.cache_path)

    return {}
