

def p(name, util=False):
    base_path = "../../R/"
    if (util): base_path += "utils/"
    return (base_path + name + ".R")
    
CLASSIFY_BUILDING_TYPES = p("BuildingTypeClassification")
ESTIMATE_HEIGHTS = p("HeightEstimation")
PREPARE_OSM_DATA = p("OsmDataPrep")
ASSIGN_ACTIVITY_LOCATIONS = p("ActivityLocations")
ESTIMATE_RESIDENTS_WORKPLACES = p("ResidentsWorkplacesEstimation")
CREATE_SYNTHETIC_POP = p("SyntheticPop")
CALC_TRAVEL_TIMES = p("TravelTimes")
ASSIGN_TRIP_CHAIN = p("TripChainAssignment")

GET_OSM = p("OsmDataApiDownload", True)
GET_PROJECTION_NAME = p("UtmProjectionName", True)
GET_COUNTRY_DEMOGRAPHICS = p("CountryDemographicsCensusBureauApiAccess", True)
GET_CITY_POPULATION = p("CityPopulationWikidataApiAccess", True)
GET_UNEMPLOYMENT_RATE = p("UnemploymentRateWorldbankApiAccess", True)

