import tqdm
import pipeline
import yaml
import sys

if len(sys.argv) == 1:
    with open('config.yml') as f:
	    config = yaml.load(f)
elif len(sys.argv) == 2:
	with open(sys.argv[1]) as f:
	    config = yaml.load(f)
elif len(sys.argv) == 4:
	config = {"city_name": sys.argv[1], "country_name": sys.argv[2], "sample_size": sys.argv[3], 
			  "target_path": "pipeline_cache", "stages":["matsim.run"]}
elif len(sys.argv) != 1:
	raise RuntimeError("Wrong number of arguments. Please supply either config file path or <city_name> <country_name> <sample_size>.")

if "disable_progress_bar" in config and config["disable_progress_bar"]:
    tqdm.tqdm = pipeline.safe_tqdm

# use only stage names for running
requested_stages = config["stages"][:]
for i in range(len(requested_stages)):
        if type(requested_stages[i]) == dict:
            requested_stages[i] = list(requested_stages[i].keys())[0]

pipeline.run(
    requested_stages,
    target_path = config["target_path"],
    config = config)
