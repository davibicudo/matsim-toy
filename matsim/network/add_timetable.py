import os.path

def configure(context, require):
    require.stage("matsim.java.add_timetable_compile")
    require.stage("utils.java")
    require.stage("matsim.network.mapped")
    
def execute(context):
    jar = context.stage("matsim.java.add_timetable_compile")
    java = context.stage("utils.java")

    args_dict = context.args(__loader__.name)
    args = [context.stage("matsim.network.mapped")["schedule"],
            context.stage("matsim.network.mapped")["network"],
            "%s/timetable_schedule.xml.gz" % context.cache_path,
            "%s/timetable_vehicles.xml.gz" % context.cache_path,
            args_dict.get("timetable_route_delay_factor", "1.5"),
            args_dict.get("timetable_modes", "bus,train,tram,trolleybus,light_rail"),
            args_dict.get("timetable_frequencies", "15,30,10,10,15")]
    
    java(jar, "mtoy.AddTimetableToOsmSchedule", args, cwd = context.cache_path)

    assert(os.path.exists("%s/timetable_schedule.xml.gz" % context.cache_path))
    assert(os.path.exists("%s/timetable_vehicles.xml.gz" % context.cache_path))

    return {
        "schedule" : "%s/timetable_schedule.xml.gz" % context.cache_path,
        "vehicles" : "%s/timetable_vehicles.xml.gz" % context.cache_path
    }

