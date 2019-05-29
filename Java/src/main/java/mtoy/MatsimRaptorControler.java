package mtoy;

import org.matsim.core.controler.AbstractModule;
import org.matsim.core.controler.Controler;

import ch.sbb.matsim.mobsim.qsim.SBBQSimModule;
import ch.sbb.matsim.routing.pt.raptor.SwissRailRaptorModule;

public class MatsimRaptorControler {  

	public static void main(String[] args) {
		
		Controler controler = new Controler(args[0]);
		
		controler.addOverridingModule(new AbstractModule() {
			@Override
			public void install() {
				// To use the deterministic pt simulation:
				install(new SBBQSimModule());

				// To use the fast pt router:
				install(new SwissRailRaptorModule());
			}
		});

		controler.run();

	}

}
