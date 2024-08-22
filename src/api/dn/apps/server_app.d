module api.dn.apps.server_app;

import api.core.apps.cli_app : CliApp;

/**
 * Authors: initkfs
 */
class ServerApp : CliApp
{

    override void run()
    {
        super.run;

        import api.dn.main_controller : MainController;

        auto mainController = new MainController;
        uservices.build(mainController);

        mainController.initialize;
        assert(mainController.isInitialized);
        mainController.create;
        assert(mainController.isCreated);
        mainController.run;
        assert(mainController.isRunning);

    }

}
