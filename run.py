import tqdm
import pipeline
import yaml
import sys

config_path = "config.yml"
city_name = None
print(sys.argv)
if len(sys.argv) == 2:
    config_path == sys.argv[1]
elif len(sys.argv) == 4:
	city_name = sys.argv[1]
	country_name = sys.argv[2]
	sample_size  = sys.argv[3]
elif len(sys.argv) != 1:
	raise RuntimeError("Wrong number of arguments")

with open(config_path) as f:
    config = yaml.load(f)

# adapt location names
if city_name is not None:
	config["city_name"] = city_name
	config["country_name"] = country_name
	config["sample_size"] = sample_size

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
