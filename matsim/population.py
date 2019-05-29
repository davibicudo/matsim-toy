import gzip
from tqdm import tqdm
import io
import matsim.writers as w
import pandas as pd
import numpy as np

def configure(context, require):
    require.stage("population.assign_trip_chains")

class PersonWriter:
    def __init__(self, person):
        self.person = person
        self.activities = []

    def add_activity(self, activity):
        self.activities.append(activity)

    def write(self, writer):
        if not (pd.isna(self.person['pAct_id'])):
            writer.start_person(self.person[0])

            # Attributes
            writer.start_attributes()
            writer.add_attribute("age", "java.lang.Integer", str(self.person['age']))
            writer.add_attribute("employed", "java.lang.Boolean", writer.true_false(self.person['employed']))
            writer.add_attribute("hasLicense", "java.lang.String", writer.yes_no(self.person['has_license']))
            writer.add_attribute("sex", "java.lang.String", self.person['sex'])
            writer.add_attribute("carAvail", "java.lang.String", self.person['car_avail'])
            writer.end_attributes()

            # Plan
            writer.start_plan(selected = True)
            #"","X","age","sex","employed","car_avail","studying","home_id","home_x","home_y","has_license","pAct_id","pAct_x","pAct_y","sAct_id","sAct_x","sAct_y","pAct_start","pAct_dur","pAct_type","home_pAct_ttime","main_mode","home_end","sAct_start","sAct_dur","sAct_type"
            # write home
            home_location = writer.location(self.person['home_x'], self.person['home_y'])
            writer.start_activity("home", home_location, None, self.person['home_end'])
            writer.end_activity()

            # write going leg
            writer.add_leg(self.person['main_mode'], self.person['home_end'], self.person['pAct_ttime'])

            # write primary activity
            primary_act_location = writer.location(self.person['pAct_x'], self.person['pAct_y'])
            writer.start_activity(self.person['pAct_type'], primary_act_location, self.person['pAct_start'], self.person['pAct_start'] + self.person['pAct_dur'])
            writer.end_activity()
            
            last_leg_ttime = self.person['pAct_ttime']
            last_dep_time = self.person['pAct_start'] + self.person['pAct_dur']
            # if secondary activity is present
            if (isinstance(self.person['sAct_type'], str)):
                # write leg to secondary activity
                writer.add_leg(self.person['main_mode'], self.person['pAct_start'] + self.person['pAct_dur'], 1 if np.isnan(self.person['sAct_ttime_sh']) else self.person['sAct_ttime_sh'])
                # write secondary activity
                secondary_act_location = writer.location(self.person['sAct_x'], self.person['sAct_y'])
                writer.start_activity(self.person['sAct_type'], secondary_act_location, self.person['sAct_start'], self.person['sAct_start'] + self.person['sAct_dur'])
                writer.end_activity()
                # get times for last leg/act
                last_leg_ttime = 1 if np.isnan(self.person['sAct_ttime_sh']) else self.person['sAct_ttime_sh']
                last_dep_time = self.person['sAct_start'] + self.person['sAct_dur']
            
            # write returning home leg
            writer.add_leg(self.person['main_mode'], last_dep_time, last_leg_ttime)

            # write last home activity
            writer.start_activity("home", home_location, last_dep_time + last_leg_ttime, None)
            writer.end_activity()

            writer.end_plan()
            writer.end_person()

PERSON_FIELDS = ["person_id", "age", "car_availability", "employed", "driving_license", "sex", "home_x", "home_y"]
ACTIVITY_FIELDS = ["person_id", "activity_id", "start_time", "end_time", "duration", "purpose", "is_last", "location_x", "location_y", "location_id", "following_mode", "ov_guteklasse"]

def execute(context):
    cache_path = context.cache_path
    
    df_persons = pd.read_csv(context.stage("population.assign_trip_chains"))
    
    person_iterator = iter(df_persons.iterrows())
    
    number_of_written_persons = 0
    
    with gzip.open("%s/population.xml.gz" % cache_path, "w+") as f:
        with io.BufferedWriter(f, buffer_size = 1024  * 1024 * 1024 * 2) as raw_writer:
            writer = w.PopulationWriter(raw_writer)
            writer.start_population()
    
            with tqdm(total = len(df_persons), desc = "Writing persons ...") as progress:
                try:
                    while True:
                        _, person = next(person_iterator)
    
                        person_writer = PersonWriter(person)
    
                        person_writer.write(writer)
                        number_of_written_persons += 1
                        progress.update()
                except StopIteration:
                    pass
    
            writer.end_population()
    
            assert(number_of_written_persons == len(df_persons))
    
        return "%s/population.xml.gz" % cache_path
