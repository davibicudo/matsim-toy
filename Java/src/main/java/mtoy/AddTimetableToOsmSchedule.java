package mtoy;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import org.apache.log4j.Logger;
import org.matsim.api.core.v01.Coord;
import org.matsim.api.core.v01.Id;
import org.matsim.api.core.v01.network.Network;
import org.matsim.api.core.v01.network.Node;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.config.groups.PlansCalcRouteConfigGroup.ModeRoutingParams;
import org.matsim.core.router.util.LeastCostPathCalculator.Path;
import org.matsim.core.utils.geometry.CoordUtils;
import org.matsim.pt.transitSchedule.api.Departure;
import org.matsim.pt.transitSchedule.api.TransitLine;
import org.matsim.pt.transitSchedule.api.TransitRoute;
import org.matsim.pt.transitSchedule.api.TransitRouteStop;
import org.matsim.pt.transitSchedule.api.TransitSchedule;
import org.matsim.pt.transitSchedule.api.TransitScheduleFactory;
import org.matsim.pt2matsim.config.PublicTransitMappingConfigGroup;
import org.matsim.pt2matsim.config.PublicTransitMappingConfigGroup.TransportModeAssignment;
import org.matsim.pt2matsim.mapping.networkRouter.ScheduleRouters;
import org.matsim.pt2matsim.mapping.networkRouter.ScheduleRoutersFactory;
import org.matsim.pt2matsim.mapping.networkRouter.ScheduleRoutersStandard;
import org.matsim.pt2matsim.mapping.networkRouter.ScheduleRoutersStandard.Factory;
import org.matsim.pt2matsim.tools.NetworkTools;
import org.matsim.pt2matsim.tools.ScheduleTools;
import org.matsim.vehicles.VehicleUtils;
import org.matsim.vehicles.Vehicles;

public class AddTimetableToOsmSchedule {
	
	/**
	 * Converts the available public transit data of an osm file to a MATSim transit schedule
	 * @param args [0] input mapped schedule file
	 *             [1] input mapped network file
 	 *             [2] output schedule file
 	 *             [3] output vehicles file
	 *             [4] travel time delay factor 
	 *             [5] comma-separated list of modes
	 *             [6] comma-separated list of departure frequencies (will be spread between 6AM to 9PM)
	 */
	public static void main(final String[] args) {
		System.err.println("printing args...");
		if(args.length == 7) {
			for (String a : args) {
				System.out.println(a);
			}
			run(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
		} else {
			throw new IllegalArgumentException("Wrong number of arguments");
		}
	}
	
	private static void run(String inputSchedule, String inputNetwork, String outputSchedule, String outputVehicles, String travelTimeDelayFactorStr, String modesStr, String frequenciesStr) {
		Network network = NetworkTools.readNetwork(inputNetwork);
		TransitSchedule schedule = ScheduleTools.readTransitSchedule(inputSchedule);
		
		double travelTimeDelayFactor = Double.valueOf(travelTimeDelayFactorStr);
		
		String[] modesArr = modesStr.split(",");
		Arrays.stream(modesArr).forEach(m -> m.trim());
		String[] frequenciesArr = frequenciesStr.split(",");
		Arrays.stream(frequenciesArr).forEach(f -> f.trim());
		
		if(modesArr.length != frequenciesArr.length) {
			throw new IllegalArgumentException("Number of modes and frequencies differ.");
		}
		
		Map<String, Double> modesFrequencies = new HashMap<>();
		for (int i = 0; i<modesArr.length; i++) {
			modesFrequencies.put(modesArr[i], Double.valueOf(frequenciesArr[i]));
		}

		Vehicles vehicles = VehicleUtils.createVehiclesContainer();
		TransitSchedule timetableSchedule = run(schedule, network, travelTimeDelayFactor, modesFrequencies);
		
		adjustModesTypes(timetableSchedule);
		ScheduleTools.createVehicles(timetableSchedule, vehicles);
		
		ScheduleTools.writeTransitSchedule(timetableSchedule, outputSchedule);
		ScheduleTools.writeVehicles(vehicles, outputVehicles);
	}
	
	public static TransitSchedule run(TransitSchedule schedule, Network network, double travelTimeDelayFactor, Map<String, Double> frequencies) {
		// get factory and routers
		TransitScheduleFactory factory = schedule.getFactory();
		PublicTransitMappingConfigGroup config = PublicTransitMappingConfigGroup.createDefaultConfig();
		String[] modes = {"trolleybus", "tram", "light_rail", "funicular", "subway"};
		String[] networkModes = {"car,bus", "tram", "light_rail", "light_rail,rail", "light_rail,rail"};
		for (int i=0; i<modes.length; i++) { 
			TransportModeAssignment tma = new TransportModeAssignment(modes[i]);
			tma.setNetworkModesStr(networkModes[i]);
			config.addParameterSet(tma);
		}
		
		ScheduleRoutersFactory f = new Factory(schedule, network, config.getTransportModeAssignment(), PublicTransitMappingConfigGroup.TravelCostType.linkLength, true);
		ScheduleRouters routers = f.createInstance();
		
		
		for (TransitLine line : schedule.getTransitLines().values()) {
			ArrayList<TransitRoute> newRoutes = new ArrayList<>();
			ArrayList<TransitRoute> oldRoutes = new ArrayList<>();
			for (TransitRoute route : line.getRoutes().values()) {
				ArrayList<TransitRouteStop> newStops = new ArrayList<>();
				TransitRouteStop previousStop = null;
				double cumTravelTime = 0.0;
				for (TransitRouteStop stop : route.getStops()) {
					// calculate travel times between stops and use this as offsets
					if (previousStop == null) {
						newStops.add(factory.createTransitRouteStop(stop.getStopFacility(), 60, 60));
					} else {
						Id<Node> fromNode = network.getLinks().get(previousStop.getStopFacility().getLinkId()).getFromNode().getId();
						Id<Node> toNode = network.getLinks().get(stop.getStopFacility().getLinkId()).getFromNode().getId();
						Path path = routers.calcLeastCostPath(fromNode, toNode, line, route);
						if(path == null) { // TODO: add also case for artificial links
							Logger.getLogger(ScheduleRoutersStandard.class)
							.warn("Could not find path between stops " + previousStop.getStopFacility().getId() + 
									" and " + stop.getStopFacility().getId() + 
									". Falling back to teleportation travel time (using default config plansCalcRoute parameters)");
							cumTravelTime += getTeleportedTravelTime(previousStop.getStopFacility().getCoord(), stop.getStopFacility().getCoord(), route.getTransportMode());
						} else {
							cumTravelTime += path.travelTime*travelTimeDelayFactor;
						}
						newStops.add(factory.createTransitRouteStop(stop.getStopFacility(), cumTravelTime, cumTravelTime));
					}
					previousStop = stop;
				}
				// create new route and replace old one in TransitLine
				TransitRoute newRoute = factory.createTransitRoute(route.getId(), route.getRoute(), newStops, route.getTransportMode());
				oldRoutes.add(route);
				newRoutes.add(newRoute);
				
				// add departures (from 6h to 21h)
				if (frequencies.get(newRoute.getTransportMode()) == null) { break; }
				double frequency = frequencies.get(newRoute.getTransportMode());
				int numDepartures = (int) ((21*60 - 6*60)/frequency); 
				for (int i = 1; i <= numDepartures; i++) {
					Departure departure = factory.createDeparture(Id.create(i, Departure.class), 6*3600+i*frequency*60);
					newRoute.addDeparture(departure);
				}
			}
			for (TransitRoute rt : oldRoutes) line.removeRoute(rt);
			for (TransitRoute rt : newRoutes) line.addRoute(rt);
		}

		return schedule;
	}
	
	static Config config = ConfigUtils.createConfig();
	
	static double getTeleportedTravelTime(Coord fromCoord, Coord toCoord, String mode) {
		ModeRoutingParams mrp = config.plansCalcRoute().getModeRoutingParams().get(mode);
		if (mrp == null || mrp.getTeleportedModeSpeed() == null) {
			mrp = config.plansCalcRoute().getModeRoutingParams().get("undefined");
		}
		double dist = CoordUtils.calcEuclideanDistance(fromCoord, toCoord);
		double estimatedNetworkDistance = dist * mrp.getBeelineDistanceFactor();
		int travTime = (int) (estimatedNetworkDistance / mrp.getTeleportedModeSpeed());
		
		return travTime;
	}
	
	private static void adjustModesTypes(TransitSchedule timetableSchedule) {
		for (TransitLine line : timetableSchedule.getTransitLines().values()) {
			for (TransitRoute route : line.getRoutes().values()) {
				if (route.getTransportMode().equals("trolleybus")) {
					route.setTransportMode("TRO");
				}
				if (route.getTransportMode().equals("train")) {
					route.setTransportMode("RAIL");
				}
			}
		}
	}

}
