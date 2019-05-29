import os.path

def configure(context, require):
    require.stage("matsim.java.pt2matsim")
    require.stage("utils.java")
    require.stage("population.utils.get_osm")
    require.stage("population.utils.get_projection_name")


def execute(context):
    jar = context.stage("matsim.java.pt2matsim")
    java = context.stage("utils.java")

    # Create MATSim network

    java(jar, "org.matsim.pt2matsim.run.CreateDefaultOsmConfig", [
        "convert_network_template.xml"
    ], cwd = context.cache_path)

    content = open("%s/convert_network_template.xml" % context.cache_path).read()

    content = content.replace(
        '<param name="osmFile" value="null" />',
        '<param name="osmFile" value="%s" />' % context.stage("population.utils.get_osm")
    )
    content = content.replace(
        '<param name="outputCoordinateSystem" value="null" />',
        '<param name="outputCoordinateSystem" value="%s" />' % context.stage("population.utils.get_projection_name")
    )
    content = content.replace(
        '<param name="outputNetworkFile" value="null" />',
        '<param name="outputNetworkFile" value="%s/converted_network.xml.gz" />' % context.cache_path
    )

    with open("%s/convert_network.xml" % context.cache_path, "w+") as f:
        f.write(content)

    java(jar, "org.matsim.pt2matsim.run.Osm2MultimodalNetwork", [
        "convert_network.xml"
    ], cwd = context.cache_path)

    assert(os.path.exists("%s/converted_network.xml.gz" % context.cache_path))
    return "%s/converted_network.xml.gz" % context.cache_path
