import tqdm
import pipeline
import yaml
import sys

config_path = "config.yml"

if len(sys.argv) > 1:
    config_path = sys.argv[1]

with open(config_path) as f:
    config = yaml.load(f)

if "disable_progress_bar" in config and config["disable_progress_bar"]:
    tqdm.tqdm = pipeline.safe_tqdm

# use only stage names for running
requested_stages = config["stages"][:]
for i in range(len(requested_stages)):
        if type(requested_stages[i]) == dict:
            requested_stages[i] = list(requested_stages[i].keys())[0]


import time

start = time.time()
pipeline.run(
    requested_stages,
    target_path = config["target_path"],
    config = config)
end = time.time()
print(end - start)

