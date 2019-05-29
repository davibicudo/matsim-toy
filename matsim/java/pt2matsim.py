import requests
from tqdm import tqdm
import subprocess as sp
import os.path

def configure(context, require):
    require.stage("utils.java")
    require.config("maven_path", "mvn")

def execute(context):
    java = context.stage("utils.java")
    mvn = context.config["maven_path"]

    sp.check_call([
        "git", "clone", "https://github.com/matsim-org/pt2matsim.git"
    ], cwd = context.cache_path)

    sp.check_call([
        "git", "checkout", "fb4e748" # commit id with solved Osm2TransitSchedule issues
    ], cwd = "%s/pt2matsim" % context.cache_path)

    sp.check_call([
        mvn, "-version"
    ], cwd = "%s/pt2matsim" % context.cache_path)

    sp.check_call([
        mvn, "package"
    ], cwd = "%s/pt2matsim" % context.cache_path)

    jar = "%s/pt2matsim/target/pt2matsim-19.2-shaded.jar" % context.cache_path
    java(jar, "org.matsim.pt2matsim.run.CreateDefaultOsmConfig", ["test_config.xml"], cwd = context.cache_path)

    assert(os.path.exists("%s/test_config.xml" % context.cache_path))

    return jar

def execute_backup(context):
    url = context.config["pt2matsim_url"]
    target_path = "%s/pt2matsim.jar" % context.cache_path

    r = requests.get(url, stream = True)
    total = int(r.headers["content-length"])

    with tqdm(desc = "Downloading pt2matsim", total = total) as progress:
        with open(target_path, 'wb+') as f:
            for chunk in r.iter_content(chunk_size = 1024):
                if chunk:
                    f.write(chunk)
                    progress.update(len(chunk))

    sp.check_call([
        "java", "-cp", "pt2matsim.jar", "org.matsim.pt2matsim.run.CreateDefaultOsmConfig", "test_config.xml"
    ], cwd = context.cache_path, stdout = sp.PIPE, stderr = sp.PIPE)

    assert(os.path.exists("%s/test_config.xml" % context.cache_path))
    return target_path
